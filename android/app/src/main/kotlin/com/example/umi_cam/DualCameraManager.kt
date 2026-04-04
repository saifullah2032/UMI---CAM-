package com.example.umi_cam

import android.Manifest
import android.annotation.SuppressLint
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.*
import android.hardware.camera2.*
import android.media.Image
import android.graphics.ImageFormat
import android.media.ImageReader
import android.os.Handler
import android.os.HandlerThread
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import android.util.Size
import android.view.Surface
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.atomic.AtomicReference

/**
 * DualCameraManager - Core Camera2 API orchestration for UMI 海 - CAM
 * 
 * Implements dual-camera texture pipeline with:
 * - Simultaneous front/back camera access
 * - Flutter TextureRegistry integration with Android 15+ Surface Producer support
 * - YUV→ARGB frame capture pipeline
 * - Bypass mode for unsupported devices
 * - Enhanced logging for debugging pixel format issues
 */
class DualCameraManager(
    private val context: Context,
    private val textureRegistry: TextureRegistry
) {
    companion object {
        private const val TAG = "DualCameraManager"
        private const val PREVIEW_WIDTH = 1280
        private const val PREVIEW_HEIGHT = 720
        private const val FRAME_CAPTURE_WIDTH = 640
        private const val FRAME_CAPTURE_HEIGHT = 480
        private const val FRAME_INTERVAL_MS = 33L // ~30fps limit
    }

    // Camera Management
    private var cameraManager: CameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
    private var frontCamera: CameraDevice? = null
    private var backCamera: CameraDevice? = null
    private var frontCaptureSession: CameraCaptureSession? = null
    private var backCaptureSession: CameraCaptureSession? = null
    
    // Flutter Texture Integration
    private var frontTextureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var backTextureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var frontSurfaceTexture: android.graphics.SurfaceTexture? = null
    private var backSurfaceTexture: android.graphics.SurfaceTexture? = null
    
    // Frame Capture Pipeline
    private var frontImageReader: ImageReader? = null
    private var backImageReader: ImageReader? = null
    private var frontPhotoReader: ImageReader? = null
    private var backPhotoReader: ImageReader? = null
    
    // Background Processing
    private var backgroundThread: HandlerThread? = null
    private var backgroundHandler: Handler? = null
    
    // Frame Rate Control
    private var lastFrontFrameTime = 0L
    private var lastBackFrameTime = 0L
    private var frameProcessingEnabled = false
    
    // State Management  
    private var isInitialized = false
    private var isCamerasOpen = false
    private var frontCameraReady = false
    private var backCameraReady = false
    
    // Callback for camera opening completion
    private var openCamerasCallback: ((Boolean, String?) -> Unit)? = null
    
    // Frame Storage (thread-safe)
    private val frontFrameRef = AtomicReference<Bitmap?>(null)
    private val backFrameRef = AtomicReference<Bitmap?>(null)

    /**
     * Initialize the dual camera system
     * Creates texture entries and background processing thread
     * Uses Surface Producer API for Android 15+ (API 36) compatibility
     */
    fun initialize(callback: (Boolean, String?, Map<String, Any>?) -> Unit) {
        Log.d(TAG, "Initializing DualCameraManager...")
        Log.d(TAG, "Android API Level: ${Build.VERSION.SDK_INT}")
        Log.d(TAG, "Using Surface Producer API: ${Build.VERSION.SDK_INT >= 36}")
        
        try {
            // Check if already initialized to prevent texture recreation
            if (isInitialized && frontTextureEntry != null && backTextureEntry != null) {
                val fullyOpen = frontCamera != null && backCamera != null &&
                    frontCaptureSession != null && backCaptureSession != null
                if (!fullyOpen) {
                    isCamerasOpen = false
                    frontCameraReady = false
                    backCameraReady = false
                }

                Log.d(TAG, "DualCameraManager already initialized, reusing existing textures (fullyOpen=$fullyOpen)")
                val resultData = mapOf(
                    "frontTextureId" to (frontTextureEntry?.id() ?: -1),
                    "backTextureId" to (backTextureEntry?.id() ?: -1),
                    "width" to PREVIEW_WIDTH,
                    "height" to PREVIEW_HEIGHT
                )
                callback(true, null, resultData)
                return
            }
            
            // Check camera permissions
            if (!hasRequiredPermissions()) {
                callback(false, "Camera permissions not granted", null)
                return
            }
            
            startBackgroundThread()
            
            // Only create new texture entries if we don't have valid ones
            if (frontTextureEntry == null) {
                frontTextureEntry = createCompatibleTextureEntry("front")
            }
            if (backTextureEntry == null) {
                backTextureEntry = createCompatibleTextureEntry("back")
            }
            
            frontSurfaceTexture = frontTextureEntry?.surfaceTexture()
            backSurfaceTexture = backTextureEntry?.surfaceTexture()
            
            if (frontSurfaceTexture == null || backSurfaceTexture == null) {
                callback(false, "Failed to create compatible surface textures", null)
                return
            }
            
            // Configure texture buffer sizes
            frontSurfaceTexture?.setDefaultBufferSize(PREVIEW_WIDTH, PREVIEW_HEIGHT)
            backSurfaceTexture?.setDefaultBufferSize(PREVIEW_WIDTH, PREVIEW_HEIGHT)
            
            Log.d(TAG, "Surface textures configured: ${PREVIEW_WIDTH}x$PREVIEW_HEIGHT")
            
            isInitialized = true
            
            val result = mapOf(
                "frontTextureId" to (frontTextureEntry?.id() ?: -1),
                "backTextureId" to (backTextureEntry?.id() ?: -1),
                "previewSize" to mapOf(
                    "width" to PREVIEW_WIDTH,
                    "height" to PREVIEW_HEIGHT
                ),
                "apiLevel" to Build.VERSION.SDK_INT,
                "usingSurfaceProducer" to (Build.VERSION.SDK_INT >= 36)
            )
            
            Log.d(TAG, "DualCameraManager initialized successfully")
            Log.d(TAG, "Front texture ID: ${frontTextureEntry?.id()}")
            Log.d(TAG, "Back texture ID: ${backTextureEntry?.id()}")
            
            callback(true, null, result)
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize DualCameraManager", e)
            callback(false, "Initialization failed: ${e.message}", null)
        }
    }

    /**
     * Create texture entry with Android 15+ Surface Producer compatibility
     */
    private fun createCompatibleTextureEntry(cameraName: String): TextureRegistry.SurfaceTextureEntry? {
        return try {
            val textureEntry = textureRegistry.createSurfaceTexture()
            Log.d(TAG, "$cameraName texture entry created with ID: ${textureEntry.id()}")
            
            // Flutter engine owns texture updates; avoid manual updateTexImage calls from plugin thread.
            // Manual updates can fail with invalid EGLDisplay and break preview rendering.
            if (Build.VERSION.SDK_INT >= 36) {
                Log.d(TAG, "$cameraName: Android 15+ texture mode active (engine-managed updates)")
            }
            
            textureEntry
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create $cameraName texture entry", e)
            null
        }
    }

    /**
     * Open both cameras simultaneously
     * Uses bypass mode if official dual-camera support is unavailable
     * Enhanced logging for pixel format debugging
     */
    @SuppressLint("MissingPermission")
    fun openCameras(bypassMode: Boolean = false, callback: (Boolean, String?) -> Unit) {
        Log.d(TAG, "Opening cameras (bypassMode: $bypassMode)...")
        Log.d(TAG, "System info - SDK: ${Build.VERSION.SDK_INT}, Release: ${Build.VERSION.RELEASE}")
        Log.d(TAG, "Current state - isInitialized: $isInitialized, isCamerasOpen: $isCamerasOpen")
        Log.d(TAG, "Camera devices - front: ${frontCamera != null}, back: ${backCamera != null}")
        
        if (!isInitialized) {
            callback(false, "DualCameraManager not initialized")
            return
        }
        
        if (isCamerasOpen) {
            val fullyOpen = frontCamera != null && backCamera != null &&
                frontCaptureSession != null && backCaptureSession != null
            if (fullyOpen) {
                Log.d(TAG, "✅ Cameras already open and ready")
                callback(true, null)
                return
            }

            Log.w(TAG, "⚠️ Stale open state detected; resetting camera state before reopen")
            isCamerasOpen = false
            frontCameraReady = false
            backCameraReady = false
            frontCaptureSession = null
            backCaptureSession = null
            frontCamera = null
            backCamera = null
        }
        
        try {
            // Store callback for when both cameras are ready
            openCamerasCallback = callback
            
            // Get camera IDs with enhanced validation
            val cameraIds = cameraManager.cameraIdList
            Log.d(TAG, "Available camera IDs: ${cameraIds.contentToString()}")
            
            val frontCameraId = getFrontCameraId()
            val backCameraId = getBackCameraId()
            
            if (frontCameraId == null) {
                Log.e(TAG, "❌ Front camera not available")
                callback(false, "Front camera not available")
                return
            }
            
            if (backCameraId == null) {
                Log.e(TAG, "❌ Back camera not available") 
                callback(false, "Back camera not available")
                return
            }
            
            Log.d(TAG, "✅ Camera validation complete")
            Log.d(TAG, "Front camera ID: $frontCameraId")
            Log.d(TAG, "Back camera ID: $backCameraId")
            
            // Validate pixel format support before opening
            validateCameraFormats(frontCameraId, "FRONT")
            validateCameraFormats(backCameraId, "BACK")
            
            Log.d(TAG, "🚀 Starting simultaneous camera initialization...")
            
            // Reset camera ready states
            frontCameraReady = false
            backCameraReady = false
            frameProcessingEnabled = false
            
            // Open both cameras concurrently
            Log.d(TAG, "Opening front and back cameras together...")
            cameraManager.openCamera(frontCameraId, frontCameraStateCallback, backgroundHandler)
            cameraManager.openCamera(backCameraId, backCameraStateCallback, backgroundHandler)
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to open cameras", e)
            callback(false, "Camera opening failed: ${e.message}")
        }
    }

    /**
     * Validate camera supports required formats to prevent pixel format errors
     */
    private fun validateCameraFormats(cameraId: String, cameraName: String) {
        try {
            val characteristics = cameraManager.getCameraCharacteristics(cameraId)
            val configMap = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
            
            if (configMap == null) {
                Log.w(TAG, "$cameraName camera: No stream configuration map available")
                return
            }
            
            val outputFormats = configMap.outputFormats
            Log.d(TAG, "$cameraName camera supported formats: ${outputFormats.contentToString()}")
            
            val supportsYuv420 = outputFormats.contains(ImageFormat.YUV_420_888)
            val supportsJpeg = outputFormats.contains(ImageFormat.JPEG)
            
            Log.d(TAG, "$cameraName camera format support:")
            Log.d(TAG, "  - YUV_420_888 (0x${Integer.toHexString(ImageFormat.YUV_420_888)}): $supportsYuv420")
            Log.d(TAG, "  - JPEG (0x${Integer.toHexString(ImageFormat.JPEG)}): $supportsJpeg")
            
            if (!supportsYuv420) {
                Log.w(TAG, "⚠️ $cameraName camera does not support YUV_420_888 format!")
            }
            
            if (!supportsJpeg) {
                Log.w(TAG, "⚠️ $cameraName camera does not support JPEG format!")
            }
            
            // Log available sizes for YUV_420_888
            if (supportsYuv420) {
                val yuvSizes = configMap.getOutputSizes(ImageFormat.YUV_420_888)
                Log.d(TAG, "$cameraName camera YUV_420_888 sizes: ${yuvSizes?.contentToString()}")
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to validate $cameraName camera formats", e)
        }
    }

    /**
     * Close both cameras and clean up resources
     */
    fun closeCameras(callback: (Boolean, String?) -> Unit) {
        Log.d(TAG, "Closing cameras...")
        
        try {
            // Close capture sessions first (required before closing devices)
            try {
                frontCaptureSession?.stopRepeating()
            } catch (_: Exception) {}
            try {
                backCaptureSession?.stopRepeating()
            } catch (_: Exception) {}
            try {
                frontCaptureSession?.abortCaptures()
            } catch (_: Exception) {}
            try {
                backCaptureSession?.abortCaptures()
            } catch (_: Exception) {}

            frontCaptureSession?.close()
            backCaptureSession?.close()
            frontCaptureSession = null
            backCaptureSession = null
            
            // Close cameras
            frontCamera?.close()
            backCamera?.close()
            frontCamera = null
            backCamera = null
            
            // Close image readers
            frontImageReader?.close()
            backImageReader?.close()
            frontPhotoReader?.close()
            backPhotoReader?.close()
            frontImageReader = null
            backImageReader = null
            frontPhotoReader = null
            backPhotoReader = null
            
            isCamerasOpen = false
            frontCameraReady = false
            backCameraReady = false
            frameProcessingEnabled = false
            
            Log.d(TAG, "Cameras closed successfully")
            callback(true, null)
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to close cameras", e)
            callback(false, "Camera closing failed: ${e.message}")
        }
    }

    /**
     * Clean up all resources
     */
    fun dispose() {
        Log.d(TAG, "Disposing DualCameraManager...")
        
        // First close cameras and sessions properly
        closeCameras { _, _ -> }
        
        // Wait a bit for sessions to fully close
        try {
            Thread.sleep(100)
        } catch (e: InterruptedException) {
            Thread.currentThread().interrupt()
        }
        
        // Clean up surface textures first to prevent BufferQueue abandonment
        frontSurfaceTexture?.let { surfaceTexture ->
            try {
                surfaceTexture.setOnFrameAvailableListener(null)
                Log.d(TAG, "Front surface texture listener cleared")
            } catch (e: Exception) {
                Log.w(TAG, "Error clearing front surface texture listener", e)
            }
        }
        
        backSurfaceTexture?.let { surfaceTexture ->
            try {
                surfaceTexture.setOnFrameAvailableListener(null)
                Log.d(TAG, "Back surface texture listener cleared")
            } catch (e: Exception) {
                Log.w(TAG, "Error clearing back surface texture listener", e)
            }
        }
        
        frontSurfaceTexture = null
        backSurfaceTexture = null
        
        // Release texture entries safely
        try {
            frontTextureEntry?.release()
            Log.d(TAG, "Front texture entry released successfully")
        } catch (e: RuntimeException) {
            if (e.message?.contains("FlutterJNI is not attached to native") == true) {
                Log.w(TAG, "FlutterJNI already detached, skipping front texture cleanup: ${e.message}")
            } else {
                Log.e(TAG, "Error releasing front texture entry", e)
            }
        }
        
        try {
            backTextureEntry?.release()
            Log.d(TAG, "Back texture entry released successfully")
        } catch (e: RuntimeException) {
            if (e.message?.contains("FlutterJNI is not attached to native") == true) {
                Log.w(TAG, "FlutterJNI already detached, skipping back texture cleanup: ${e.message}")
            } else {
                Log.e(TAG, "Error releasing back texture entry", e)
            }
        }
        
        frontTextureEntry = null
        backTextureEntry = null
        
        stopBackgroundThread()
        
        isInitialized = false
        frontCameraReady = false
        backCameraReady = false
        Log.d(TAG, "DualCameraManager disposed safely with proper texture cleanup")
    }

    // ============================================================
    // PRIVATE IMPLEMENTATION
    // ============================================================

    private fun hasRequiredPermissions(): Boolean {
        return ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
    }

    private fun getFrontCameraId(): String? {
        return try {
            cameraManager.cameraIdList.firstOrNull { id ->
                val characteristics = cameraManager.getCameraCharacteristics(id)
                characteristics.get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_FRONT
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting front camera ID", e)
            null
        }
    }

    private fun getBackCameraId(): String? {
        return try {
            cameraManager.cameraIdList.firstOrNull { id ->
                val characteristics = cameraManager.getCameraCharacteristics(id)
                characteristics.get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_BACK
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting back camera ID", e)
            null
        }
    }

    private fun startBackgroundThread() {
        backgroundThread = HandlerThread("CameraBackground").also { it.start() }
        backgroundHandler = Handler(backgroundThread!!.looper)
    }

    private fun stopBackgroundThread() {
        backgroundThread?.quitSafely()
        try {
            backgroundThread?.join()
            backgroundThread = null
            backgroundHandler = null
        } catch (e: InterruptedException) {
            Log.e(TAG, "Error stopping background thread", e)
        }
    }

    // ============================================================
    // CAMERA STATE CALLBACKS
    // ============================================================

    private val frontCameraStateCallback = object : CameraDevice.StateCallback() {
        override fun onOpened(camera: CameraDevice) {
            Log.d(TAG, "✅ FRONT CAMERA OPENED SUCCESSFULLY")
            Log.d(TAG, "Front camera device ID: ${camera.id}")
            try {
                val characteristics = cameraManager.getCameraCharacteristics(camera.id)
                val facing = characteristics.get(CameraCharacteristics.LENS_FACING)
                val supportedFormats = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)?.outputFormats
                Log.d(TAG, "Front camera facing: $facing")
                Log.d(TAG, "Front camera supported formats: ${supportedFormats?.contentToString()}")
            } catch (e: Exception) {
                Log.w(TAG, "Could not get front camera characteristics", e)
            }
            frontCamera = camera
            createFrontCaptureSession()
        }

        override fun onDisconnected(camera: CameraDevice) {
            Log.w(TAG, "❌ FRONT CAMERA DISCONNECTED")
            Log.w(TAG, "Front camera device ID: ${camera.id}")
            camera.close()
            frontCamera = null
            frontCaptureSession = null
            frontCameraReady = false
            isCamerasOpen = false
        }

        override fun onError(camera: CameraDevice, error: Int) {
            Log.e(TAG, "❌ FRONT CAMERA ERROR: $error")
            Log.e(TAG, "Front camera device ID: ${camera.id}")
            Log.e(TAG, "Error codes: CAMERA_IN_USE=1, MAX_CAMERAS_IN_USE=2, CAMERA_DISABLED=3, CAMERA_DEVICE=4, CAMERA_SERVICE=5")
            when (error) {
                CameraDevice.StateCallback.ERROR_CAMERA_IN_USE -> Log.e(TAG, "Front camera is already in use by another app")
                CameraDevice.StateCallback.ERROR_MAX_CAMERAS_IN_USE -> Log.e(TAG, "Maximum number of cameras in use")
                CameraDevice.StateCallback.ERROR_CAMERA_DISABLED -> Log.e(TAG, "Front camera is disabled by device policy")
                CameraDevice.StateCallback.ERROR_CAMERA_DEVICE -> Log.e(TAG, "Front camera device has encountered a fatal error")
                CameraDevice.StateCallback.ERROR_CAMERA_SERVICE -> Log.e(TAG, "Camera service has encountered a fatal error")
            }
            camera.close()
            frontCamera = null
            frontCaptureSession = null
            frontCameraReady = false
            isCamerasOpen = false
            
            // Call error callback
            openCamerasCallback?.let {
                it(false, "Front camera error: $error")
                openCamerasCallback = null
            }
        }
    }

    private val backCameraStateCallback = object : CameraDevice.StateCallback() {
        override fun onOpened(camera: CameraDevice) {
            Log.d(TAG, "✅ BACK CAMERA OPENED SUCCESSFULLY")
            Log.d(TAG, "Back camera device ID: ${camera.id}")
            try {
                val characteristics = cameraManager.getCameraCharacteristics(camera.id)
                val facing = characteristics.get(CameraCharacteristics.LENS_FACING)
                val supportedFormats = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)?.outputFormats
                Log.d(TAG, "Back camera facing: $facing")
                Log.d(TAG, "Back camera supported formats: ${supportedFormats?.contentToString()}")
            } catch (e: Exception) {
                Log.w(TAG, "Could not get back camera characteristics", e)
            }
            backCamera = camera
            createBackCaptureSession()
        }

        override fun onDisconnected(camera: CameraDevice) {
            Log.w(TAG, "❌ BACK CAMERA DISCONNECTED")
            Log.w(TAG, "Back camera device ID: ${camera.id}")
            camera.close()
            backCamera = null
            backCaptureSession = null
            backCameraReady = false
            isCamerasOpen = false
        }

        override fun onError(camera: CameraDevice, error: Int) {
            Log.e(TAG, "❌ BACK CAMERA ERROR: $error")
            Log.e(TAG, "Back camera device ID: ${camera.id}")
            Log.e(TAG, "Error codes: CAMERA_IN_USE=1, MAX_CAMERAS_IN_USE=2, CAMERA_DISABLED=3, CAMERA_DEVICE=4, CAMERA_SERVICE=5")
            when (error) {
                CameraDevice.StateCallback.ERROR_CAMERA_IN_USE -> Log.e(TAG, "Back camera is already in use by another app")
                CameraDevice.StateCallback.ERROR_MAX_CAMERAS_IN_USE -> Log.e(TAG, "Maximum number of cameras in use")
                CameraDevice.StateCallback.ERROR_CAMERA_DISABLED -> Log.e(TAG, "Back camera is disabled by device policy")
                CameraDevice.StateCallback.ERROR_CAMERA_DEVICE -> Log.e(TAG, "Back camera device has encountered a fatal error")
                CameraDevice.StateCallback.ERROR_CAMERA_SERVICE -> Log.e(TAG, "Camera service has encountered a fatal error")
            }
            camera.close()
            backCamera = null
            backCaptureSession = null
            backCameraReady = false
            isCamerasOpen = false
            
            // Call error callback
            openCamerasCallback?.let {
                it(false, "Back camera error: $error")
                openCamerasCallback = null
            }
        }
    }

    // ============================================================
    // CAPTURE SESSION CREATION
    // ============================================================

    private fun createFrontCaptureSession() {
        val camera = frontCamera ?: return
        val surfaceTexture = frontSurfaceTexture ?: return
        
        Log.d(TAG, "🔧 Creating front camera capture session...")
        
        try {
            // Preview surface for Flutter display
            val previewSurface = Surface(surfaceTexture)
            Log.d(TAG, "Front preview surface created")
            
            // Frame capture surface for composition - using YUV_420_888
            frontImageReader = ImageReader.newInstance(
                FRAME_CAPTURE_WIDTH,
                FRAME_CAPTURE_HEIGHT,
                ImageFormat.YUV_420_888,
                2
            )
            Log.d(TAG, "Front ImageReader created: ${FRAME_CAPTURE_WIDTH}x${FRAME_CAPTURE_HEIGHT}, format=YUV_420_888 (0x${Integer.toHexString(ImageFormat.YUV_420_888)})")
            
            // Photo capture surface
            frontPhotoReader = ImageReader.newInstance(
                1920, 1080,
                ImageFormat.JPEG,
                2
            )
            Log.d(TAG, "Front PhotoReader created: 1920x1080, format=JPEG (0x${Integer.toHexString(ImageFormat.JPEG)})")
            
            // Set up frame capture callback
            frontImageReader!!.setOnImageAvailableListener({ reader ->
                if (!frameProcessingEnabled) {
                    val image = reader.acquireLatestImage()
                    image?.close()
                    return@setOnImageAvailableListener
                }

                val currentTime = System.currentTimeMillis()
                if (currentTime - lastFrontFrameTime < FRAME_INTERVAL_MS) {
                    return@setOnImageAvailableListener
                }
                lastFrontFrameTime = currentTime
                
                val image = reader.acquireLatestImage()
                image?.use {
                    try {
                        val bitmap = yuvToBitmap(it, true)
                        frontFrameRef.set(bitmap)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error processing front frame", e)
                    }
                }
            }, backgroundHandler)
            
            val surfaces = listOf(
                previewSurface,
                frontImageReader!!.surface,
                frontPhotoReader!!.surface
            )
            
            Log.d(TAG, "Front session surfaces: ${surfaces.size} surfaces prepared")
            camera.createCaptureSession(surfaces, frontSessionStateCallback, backgroundHandler)
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to create front capture session", e)
        }
    }

    private fun createBackCaptureSession() {
        val camera = backCamera ?: return
        val surfaceTexture = backSurfaceTexture ?: return
        
        Log.d(TAG, "🔧 Creating back camera capture session...")
        
        try {
            // Preview surface for Flutter display
            val previewSurface = Surface(surfaceTexture)
            Log.d(TAG, "Back preview surface created")
            
            // Frame capture surface for composition - using YUV_420_888
            backImageReader = ImageReader.newInstance(
                FRAME_CAPTURE_WIDTH,
                FRAME_CAPTURE_HEIGHT,
                ImageFormat.YUV_420_888,
                2
            )
            Log.d(TAG, "Back ImageReader created: ${FRAME_CAPTURE_WIDTH}x${FRAME_CAPTURE_HEIGHT}, format=YUV_420_888 (0x${Integer.toHexString(ImageFormat.YUV_420_888)})")
            
            // Photo capture surface
            backPhotoReader = ImageReader.newInstance(
                1920, 1080,
                ImageFormat.JPEG,
                2
            )
            Log.d(TAG, "Back PhotoReader created: 1920x1080, format=JPEG (0x${Integer.toHexString(ImageFormat.JPEG)})")
            
            // Set up frame capture callback
            backImageReader!!.setOnImageAvailableListener({ reader ->
                if (!frameProcessingEnabled) {
                    val image = reader.acquireLatestImage()
                    image?.close()
                    return@setOnImageAvailableListener
                }

                val currentTime = System.currentTimeMillis()
                if (currentTime - lastBackFrameTime < FRAME_INTERVAL_MS) {
                    return@setOnImageAvailableListener
                }
                lastBackFrameTime = currentTime
                
                val image = reader.acquireLatestImage()
                image?.use {
                    try {
                        val bitmap = yuvToBitmap(it, false)
                        backFrameRef.set(bitmap)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error processing back frame", e)
                    }
                }
            }, backgroundHandler)
            
            val surfaces = listOf(
                previewSurface,
                backImageReader!!.surface,
                backPhotoReader!!.surface
            )
            
            Log.d(TAG, "Back session surfaces: ${surfaces.size} surfaces prepared")
            camera.createCaptureSession(surfaces, backSessionStateCallback, backgroundHandler)
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to create back capture session", e)
        }
    }

    // ============================================================
    // CAPTURE SESSION CALLBACKS
    // ============================================================

    private val frontSessionStateCallback = object : CameraCaptureSession.StateCallback() {
        override fun onConfigured(session: CameraCaptureSession) {
            Log.d(TAG, "✅ FRONT CAPTURE SESSION CONFIGURED")
            Log.d(TAG, "Front session surfaces: ${session.inputSurface}")
            frontCaptureSession = session
            frontCameraReady = true
            startFrontPreview()
            checkBothCamerasReady()
        }

        override fun onConfigureFailed(session: CameraCaptureSession) {
            Log.e(TAG, "❌ FRONT CAPTURE SESSION CONFIGURATION FAILED")
            Log.e(TAG, "This usually indicates incompatible surface formats or sizes")
            frontCaptureSession = null
            frontCameraReady = false
            isCamerasOpen = false
            
            // Call error callback
            openCamerasCallback?.invoke(false, "Front capture session configuration failed")
            openCamerasCallback = null
        }

        override fun onReady(session: CameraCaptureSession) {
            Log.d(TAG, "📸 Front capture session ready for requests")
        }

        override fun onActive(session: CameraCaptureSession) {
            Log.d(TAG, "🎬 Front capture session active (preview started)")
        }
    }

    private val backSessionStateCallback = object : CameraCaptureSession.StateCallback() {
        override fun onConfigured(session: CameraCaptureSession) {
            Log.d(TAG, "✅ BACK CAPTURE SESSION CONFIGURED")
            Log.d(TAG, "Back session surfaces: ${session.inputSurface}")
            backCaptureSession = session
            backCameraReady = true
            startBackPreview()
            checkBothCamerasReady()
        }

        override fun onConfigureFailed(session: CameraCaptureSession) {
            Log.e(TAG, "❌ BACK CAPTURE SESSION CONFIGURATION FAILED")
            Log.e(TAG, "This usually indicates incompatible surface formats or sizes")
            backCaptureSession = null
            backCameraReady = false
            isCamerasOpen = false
            
            // Call error callback
            openCamerasCallback?.invoke(false, "Back capture session configuration failed")
            openCamerasCallback = null
        }

        override fun onReady(session: CameraCaptureSession) {
            Log.d(TAG, "📸 Back capture session ready for requests")
        }

        override fun onActive(session: CameraCaptureSession) {
            Log.d(TAG, "🎬 Back capture session active (preview started)")
        }
    }

    private fun checkBothCamerasReady() {
        if (frontCameraReady && backCameraReady && 
            frontCaptureSession != null && backCaptureSession != null && !isCamerasOpen) {
            isCamerasOpen = true
            Log.d(TAG, "🎉 BOTH CAMERAS ARE READY AND STREAMING")
            Log.d(TAG, "Front camera status: ${frontCamera != null}")
            Log.d(TAG, "Back camera status: ${backCamera != null}")
            Log.d(TAG, "Front session status: ${frontCaptureSession != null}")
            Log.d(TAG, "Back session status: ${backCaptureSession != null}")
            Log.d(TAG, "Front ready: $frontCameraReady, Back ready: $backCameraReady")
            
            // Call the callback to notify that cameras are successfully opened
            openCamerasCallback?.invoke(true, null)
            openCamerasCallback = null // Clear the callback
        }
    }

    // ============================================================
    // PREVIEW CONTROL
    // ============================================================

    private fun startFrontPreview() {
        val session = frontCaptureSession ?: return
        val camera = frontCamera ?: return
        val surfaceTexture = frontSurfaceTexture ?: return
        
        try {
            val requestBuilder = camera.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)
            requestBuilder.addTarget(Surface(surfaceTexture))
            requestBuilder.addTarget(frontImageReader!!.surface)
            
            // Set continuous auto-focus
            requestBuilder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_VIDEO)
            requestBuilder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)
            
            session.setRepeatingRequest(requestBuilder.build(), null, backgroundHandler)
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start front preview", e)
        }
    }

    private fun startBackPreview() {
        val session = backCaptureSession ?: return
        val camera = backCamera ?: return
        val surfaceTexture = backSurfaceTexture ?: return
        
        try {
            val requestBuilder = camera.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)
            requestBuilder.addTarget(Surface(surfaceTexture))
            requestBuilder.addTarget(backImageReader!!.surface)
            
            // Set continuous auto-focus
            requestBuilder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_VIDEO)
            requestBuilder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)
            
            session.setRepeatingRequest(requestBuilder.build(), null, backgroundHandler)
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start back preview", e)
        }
    }

    // ============================================================
    // FRAME PROCESSING
    // ============================================================

    /**
     * Convert YUV_420_888 Image to ARGB Bitmap
     * Optimized for real-time processing
     */
    private fun yuvToBitmap(image: Image, isFront: Boolean): Bitmap {
        val yBuffer = image.planes[0].buffer
        val uBuffer = image.planes[1].buffer
        val vBuffer = image.planes[2].buffer

        val ySize = yBuffer.remaining()
        val uSize = uBuffer.remaining()
        val vSize = vBuffer.remaining()

        val nv21 = ByteArray(ySize + uSize + vSize)

        // U and V are swapped
        yBuffer.get(nv21, 0, ySize)
        vBuffer.get(nv21, ySize, vSize)
        uBuffer.get(nv21, ySize + vSize, uSize)

        val yuvImage = YuvImage(
            nv21,
            ImageFormat.NV21,
            image.width,
            image.height,
            null
        )

        val out = ByteArrayOutputStream()
        yuvImage.compressToJpeg(
            Rect(0, 0, image.width, image.height),
            85, // Compress to reduce memory usage
            out
        )

        val decoded = BitmapFactory.decodeByteArray(
            out.toByteArray(),
            0,
            out.size()
        )

        val matrix = Matrix()
        if (isFront) {
            matrix.postRotate(270f)
            matrix.postScale(-1f, 1f)
        } else {
            matrix.postRotate(90f)
        }

        return Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true)
    }

    /**
     * Get current front camera frame (thread-safe)
     */
    fun getCurrentFrontFrame(): Bitmap? {
        return frontFrameRef.get()
    }

    /**
     * Get current back camera frame (thread-safe)
     */
    fun getCurrentBackFrame(): Bitmap? {
        return backFrameRef.get()
    }

    fun setFrameProcessingEnabled(enabled: Boolean) {
        frameProcessingEnabled = enabled
        Log.d(TAG, "Frame processing ${if (enabled) "enabled" else "disabled"}")
    }

    fun getTextureIds(): Map<String, Any> {
        return mapOf(
            "frontTextureId" to (frontTextureEntry?.id() ?: -1L),
            "backTextureId" to (backTextureEntry?.id() ?: -1L)
        )
    }

    fun getCameraInfo(): Map<String, Any> {
        val frontId = getFrontCameraId()
        val backId = getBackCameraId()
        val concurrentSupported = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            cameraManager.concurrentCameraIds.any { ids ->
                frontId != null && backId != null && ids.contains(frontId) && ids.contains(backId)
            }
        } else {
            false
        }

        val actualOpen = isCamerasOpen && frontCamera != null && backCamera != null &&
            frontCaptureSession != null && backCaptureSession != null

        return mapOf(
            "frontCameraId" to (frontId ?: ""),
            "backCameraId" to (backId ?: ""),
            "hasFrontCamera" to (frontId != null),
            "hasBackCamera" to (backId != null),
            "officialDualCameraSupport" to concurrentSupported,
            "isDualCameraSupported" to (frontId != null && backId != null),
            "isInitialized" to isInitialized,
            "isCamerasOpen" to actualOpen,
            "frontCameraConnected" to (frontCamera != null),
            "backCameraConnected" to (backCamera != null)
        )
    }

    /**
     * Get camera status for debugging and readiness checks
     */
    fun getCameraStatus(): Map<String, Any> {
        val frontReady = isInitialized && frontCamera != null && frontCaptureSession != null && 
                        frontTextureEntry != null && frontSurfaceTexture != null
        val backReady = isInitialized && backCamera != null && backCaptureSession != null && 
                       backTextureEntry != null && backSurfaceTexture != null
        val actualOpen = isCamerasOpen && frontCamera != null && backCamera != null &&
            frontCaptureSession != null && backCaptureSession != null
        val systemReady = frontReady && backReady && actualOpen
        
        return mapOf(
            "isInitialized" to isInitialized,
            "isCamerasOpen" to actualOpen,
            "frontCameraConnected" to (frontCamera != null),
            "backCameraConnected" to (backCamera != null),
            "frontSessionActive" to (frontCaptureSession != null),
            "backSessionActive" to (backCaptureSession != null),
            "frontTextureId" to (frontTextureEntry?.id() ?: -1),
            "backTextureId" to (backTextureEntry?.id() ?: -1),
            "frontTextureReady" to (frontTextureEntry != null && frontSurfaceTexture != null),
            "backTextureReady" to (backTextureEntry != null && backSurfaceTexture != null),
            "frontReady" to frontReady,
            "backReady" to backReady,
            "systemReady" to systemReady
        )
    }
    
     /**
      * Check if the camera system is completely ready for use
      */
     fun isSystemReady(): Boolean {
         return isInitialized && 
                isCamerasOpen && 
                frontCamera != null && 
                backCamera != null && 
                frontCaptureSession != null && 
                backCaptureSession != null && 
                frontTextureEntry != null && 
                backTextureEntry != null && 
                frontSurfaceTexture != null && 
                backSurfaceTexture != null
     }

     /**
      * Capture a high-quality dual photo from both cameras
      * Applies composition logic similar to VideoComposer
      */
     fun takePicture(callback: (Boolean, String?, String?) -> Unit) {
         if (!isSystemReady()) {
             callback(false, "Camera system not ready", null)
             return
         }

         backgroundHandler?.post {
             try {
                 Log.d(TAG, "Capturing dual photo...")

                 // Get latest frames from both cameras
                 val frontFrame = getCurrentFrontFrame()
                 val backFrame = getCurrentBackFrame()

                 if (backFrame == null) {
                     callback(false, "Back camera frame not available", null)
                     return@post
                 }

                 Log.d(TAG, "Front frame available: ${frontFrame != null}")
                 Log.d(TAG, "Back frame available: ${backFrame != null}")

                 // Create photo composition (1920x1080 ARGB_8888)
                 val photoBitmap = Bitmap.createBitmap(1920, 1080, Bitmap.Config.ARGB_8888)
                 val photoCanvas = Canvas(photoBitmap)
                 val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                     isFilterBitmap = true
                 }

                 // Draw back camera as main/full-screen
                 val mainRect = android.graphics.Rect(0, 0, 1920, 1080)
                 photoCanvas.drawBitmap(backFrame, null, mainRect, paint)

                 // Draw front camera as picture-in-picture (bottom-right corner)
                 frontFrame?.let { front ->
                     val pipSize = 480  // 25% of 1920
                     val pipMargin = 20
                     val pipX = 1920 - pipSize - pipMargin
                     val pipY = 1080 - pipSize - pipMargin
                     val pipRect = android.graphics.Rect(pipX, pipY, pipX + pipSize, pipY + pipSize)
                     photoCanvas.drawBitmap(front, null, pipRect, paint)
                 }

                  // Save photo to file
                  val photoFile = createPhotoFile()
                  savePhoto(photoBitmap, photoFile)

                  Log.d(TAG, "Photo saved: ${photoFile.absolutePath}")
                  Log.d(TAG, "Photo file exists: ${photoFile.exists()}")
                  Log.d(TAG, "Photo file size: ${photoFile.length()} bytes")

                  // Save to MediaStore DCIM/UMI-CAM for Gallery visibility
                  savePhotoToGallery(photoFile)

                  // Trigger media scanner to make it visible in Photos app
                  triggerMediaScan(photoFile)

                  // Recycle bitmap to free memory
                  photoBitmap.recycle()

                  callback(true, null, photoFile.absolutePath)

             } catch (e: Exception) {
                 Log.e(TAG, "Failed to capture photo", e)
                 callback(false, "Photo capture failed: ${e.message}", null)
             }
         }
     }

      private fun createPhotoFile(): File {
          // CRITICAL FIX: Save to Movies/UMI-CAM directory (not Downloads)
          val mediaDir = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
              // Android 10+ (API 29+): Use app-specific directory in Movies with scoped storage
              File(context.getExternalFilesDir(Environment.DIRECTORY_MOVIES), "UMI-CAM")
          } else {
              // Pre-Android 10 (API < 29): Use public Movies directory
              File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES), "UMI-CAM")
          }
          
          if (!mediaDir.exists()) {
              mediaDir.mkdirs()
          }
          
          val timestamp = System.currentTimeMillis()
          val fileName = "umi_cam_photo_$timestamp.jpg"
          return File(mediaDir, fileName)
      }

      private fun savePhoto(bitmap: Bitmap, file: File) {
          java.io.FileOutputStream(file).use { out ->
              bitmap.compress(Bitmap.CompressFormat.JPEG, 95, out)
              Log.d(TAG, "Photo compressed and saved with quality 95")
          }
      }

      /**
       * Save the captured photo to MediaStore DCIM/UMI-CAM directory
       * This makes the photo immediately visible in the device's Gallery/Photos app
       */
      private fun savePhotoToGallery(sourceFile: File) {
          if (!sourceFile.exists()) {
              Log.e(TAG, "Source photo file does not exist: ${sourceFile.absolutePath}")
              return
          }
          
          try {
              val timestamp = System.currentTimeMillis()
              val displayName = "IMG_${timestamp}_dual.jpg"
              
              // Create MediaStore entry for DCIM/UMI-CAM
              val values = ContentValues().apply {
                  put(MediaStore.Images.Media.DISPLAY_NAME, displayName)
                  put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
                  put(MediaStore.Images.Media.RELATIVE_PATH, "DCIM/UMI-CAM")
                  put(MediaStore.Images.Media.DATE_ADDED, System.currentTimeMillis() / 1000)
                  put(MediaStore.Images.Media.DATE_MODIFIED, System.currentTimeMillis() / 1000)
              }
              
              // Insert into MediaStore and get Uri
              val uri = context.contentResolver.insert(
                  MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                  values
              )
              
              if (uri == null) {
                  Log.e(TAG, "Failed to create MediaStore entry for photo")
                  return
              }
              
              // Copy photo data to MediaStore location via Uri
              context.contentResolver.openOutputStream(uri)?.use { outputStream ->
                  sourceFile.inputStream().use { inputStream ->
                      inputStream.copyTo(outputStream)
                  }
              }
              
              Log.d(TAG, "Photo saved to MediaStore: $displayName")
              Log.d(TAG, "Uri: $uri")
              Log.d(TAG, "File will appear in DCIM/UMI-CAM")
              
          } catch (e: Exception) {
              Log.e(TAG, "Error saving photo to MediaStore", e)
          }
      }

      private fun triggerMediaScan(file: File) {
         try {
             android.media.MediaScannerConnection.scanFile(
                 context,
                 arrayOf(file.absolutePath),
                 arrayOf("image/jpeg"),
                 null
             )
             Log.d(TAG, "Media scanner triggered for photo: ${file.absolutePath}")
         } catch (e: Exception) {
             Log.e(TAG, "Error triggering media scanner for photo", e)
         }
     }
 }

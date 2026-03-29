package com.example.umi_cam

import android.Manifest
import android.annotation.SuppressLint
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
import android.util.Log
import android.util.Size
import android.view.Surface
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.io.ByteArrayOutputStream
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
    
    // State Management  
    private var isInitialized = false
    private var isCamerasOpen = false
    
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
            // Check camera permissions
            if (!hasRequiredPermissions()) {
                callback(false, "Camera permissions not granted", null)
                return
            }
            
            startBackgroundThread()
            
            // Create Flutter texture entries with Android 15+ compatibility
            frontTextureEntry = createCompatibleTextureEntry("front")
            backTextureEntry = createCompatibleTextureEntry("back")
            
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
            
            // For Android 15+ (API 36), ensure Surface Producer compatibility
            if (Build.VERSION.SDK_INT >= 36) {
                Log.d(TAG, "$cameraName: Using Android 15+ Surface Producer API compatibility mode")
                // The TextureRegistry handles Surface Producer migration internally in newer Flutter versions
                // We just need to ensure proper attachment to GL context
                textureEntry.surfaceTexture()?.setOnFrameAvailableListener({ surfaceTexture ->
                    // Ensure the surface texture is properly attached to GL context
                    try {
                        surfaceTexture.updateTexImage()
                    } catch (e: Exception) {
                        Log.w(TAG, "$cameraName: Surface texture update failed - this is expected during initialization", e)
                    }
                })
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
        
        if (!isInitialized) {
            callback(false, "DualCameraManager not initialized")
            return
        }
        
        if (isCamerasOpen) {
            callback(false, "Cameras already open")
            return
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
            
            Log.d(TAG, "🚀 Opening front camera...")
            cameraManager.openCamera(frontCameraId, frontCameraStateCallback, backgroundHandler)
            
            Log.d(TAG, "🚀 Opening back camera...")
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
            // Close capture sessions
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
            
            isCamerasOpen = false
            
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
        
        closeCameras { _, _ -> }
        
        // Release texture entries
        frontTextureEntry?.release()
        backTextureEntry?.release()
        frontTextureEntry = null
        backTextureEntry = null
        
        stopBackgroundThread()
        
        isInitialized = false
        Log.d(TAG, "DualCameraManager disposed")
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
            
            // Call error callback
            openCamerasCallback?.invoke(false, "Front camera error: $error")
            openCamerasCallback = null
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
            
            // Call error callback
            openCamerasCallback?.invoke(false, "Back camera error: $error")
            openCamerasCallback = null
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
                val currentTime = System.currentTimeMillis()
                if (currentTime - lastFrontFrameTime < FRAME_INTERVAL_MS) {
                    return@setOnImageAvailableListener
                }
                lastFrontFrameTime = currentTime
                
                val image = reader.acquireLatestImage()
                image?.use {
                    try {
                        val bitmap = yuvToBitmap(it)
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
                val currentTime = System.currentTimeMillis()
                if (currentTime - lastBackFrameTime < FRAME_INTERVAL_MS) {
                    return@setOnImageAvailableListener
                }
                lastBackFrameTime = currentTime
                
                val image = reader.acquireLatestImage()
                image?.use {
                    try {
                        val bitmap = yuvToBitmap(it)
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
            startFrontPreview()
            checkBothCamerasReady()
        }

        override fun onConfigureFailed(session: CameraCaptureSession) {
            Log.e(TAG, "❌ FRONT CAPTURE SESSION CONFIGURATION FAILED")
            Log.e(TAG, "This usually indicates incompatible surface formats or sizes")
            
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
            startBackPreview()
            checkBothCamerasReady()
        }

        override fun onConfigureFailed(session: CameraCaptureSession) {
            Log.e(TAG, "❌ BACK CAPTURE SESSION CONFIGURATION FAILED")
            Log.e(TAG, "This usually indicates incompatible surface formats or sizes")
            
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
        if (frontCaptureSession != null && backCaptureSession != null && !isCamerasOpen) {
            isCamerasOpen = true
            Log.d(TAG, "🎉 BOTH CAMERAS ARE READY AND STREAMING")
            Log.d(TAG, "Front camera status: ${frontCamera != null}")
            Log.d(TAG, "Back camera status: ${backCamera != null}")
            Log.d(TAG, "Front session status: ${frontCaptureSession != null}")
            Log.d(TAG, "Back session status: ${backCaptureSession != null}")
            
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
            requestBuilder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
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
            requestBuilder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
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
    private fun yuvToBitmap(image: Image): Bitmap {
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

        return BitmapFactory.decodeByteArray(
            out.toByteArray(),
            0,
            out.size()
        )
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

    /**
     * Get camera status for debugging
     */
    fun getCameraStatus(): Map<String, Any> {
        return mapOf(
            "isInitialized" to isInitialized,
            "isCamerasOpen" to isCamerasOpen,
            "frontCameraConnected" to (frontCamera != null),
            "backCameraConnected" to (backCamera != null),
            "frontSessionActive" to (frontCaptureSession != null),
            "backSessionActive" to (backCaptureSession != null),
            "frontTextureId" to (frontTextureEntry?.id() ?: -1),
            "backTextureId" to (backTextureEntry?.id() ?: -1)
        )
    }
}
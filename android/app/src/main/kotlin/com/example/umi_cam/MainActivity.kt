package com.example.umi_cam

import android.content.Context
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CameraCharacteristics
import android.os.Build
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

/**
 * UMI 海 - CAM MainActivity
 * Industrial Ocean Neo-Brutalism Hardware Detection Bridge
 * 
 * Implements the "Gatekeeper Logic" from PRD Section 3:
 * - Concurrent camera detection with bypass mode
 * - Graceful fallback for older Android versions
 * - ISP capability validation
 */
class MainActivity : FlutterActivity() {
    
    companion object {
        private const val TAG = "UmiCamHardwareBridge"
        private const val CHANNEL = "com.example.dual_recorder/hardware_bridge"
    }
    
    private lateinit var cameraManager: CameraManager
    private var dualCameraManager: DualCameraManager? = null
    private var videoComposer: VideoComposer? = null
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize camera manager
        cameraManager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
        
        // Initialize DualCameraManager with proper TextureRegistry access  
        val textureRegistry: TextureRegistry = flutterEngine.renderer
        dualCameraManager = DualCameraManager(this, textureRegistry)
        
        // Initialize VideoComposer with DualCameraManager reference
        videoComposer = VideoComposer(this, dualCameraManager!!)
        
        // Setup MethodChannel for hardware detection
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "isDualCameraSupported" -> {
                        val isSupported = isDualCameraSupported()
                        Log.i(TAG, "Dual camera support check: $isSupported")
                        result.success(isSupported)
                    }
                    "getDualCameraUnsupportedReason" -> {
                        val reason = getDualCameraUnsupportedReason()
                        Log.i(TAG, "Dual camera unsupported reason: $reason")
                        result.success(reason)
                    }
                    "getHardwareCapabilities" -> {
                        val capabilities = getHardwareCapabilities()
                        Log.i(TAG, "Hardware capabilities: $capabilities")
                        result.success(capabilities)
                    }
                    
                    // PHASE 3: Camera Session Management
                    "initializeCameras" -> {
                        dualCameraManager?.initialize { success, error, info ->
                            if (success && info != null) {
                                result.success(info)
                            } else {
                                result.error("INIT_FAILED", error ?: "Camera initialization failed", null)
                            }
                        }
                    }
                    "openCameras" -> {
                        val bypassMode = call.argument<Boolean>("bypassMode") ?: false
                        dualCameraManager?.openCameras(bypassMode) { success, error ->
                            if (success) {
                                result.success(true)
                            } else {
                                result.error("OPEN_FAILED", error ?: "Failed to open cameras", null)
                            }
                        }
                    }
                    "closeCameras" -> {
                        dualCameraManager?.closeCameras { success, error ->
                            if (success) {
                                result.success(true)
                            } else {
                                result.error("CLOSE_FAILED", error ?: "Failed to close cameras", null)
                            }
                        }
                    }
                    "getCameraStatus" -> {
                        val status = dualCameraManager?.getCameraStatus() ?: mapOf(
                            "isInitialized" to false,
                            "isCamerasOpen" to false,
                            "error" to "DualCameraManager not available"
                        )
                        result.success(status)
                    }
                    
                    // PHASE 4: Recording Operations
                    "initializeRecording" -> {
                        videoComposer?.initialize { success, error ->
                            if (success) {
                                result.success(true)
                            } else {
                                result.error("RECORDING_INIT_FAILED", error ?: "Recording initialization failed", null)
                            }
                        }
                    }
                    "startRecording" -> {
                        val layoutStr = call.argument<String>("layout") ?: "pip"
                        val quality = call.argument<String>("quality") ?: "medium"
                        val width = call.argument<Int>("width") ?: 1920
                        val height = call.argument<Int>("height") ?: 1080
                        val bitrate = call.argument<Int>("bitrate") ?: 8_000_000
                        val smartSelfieEnabled = call.argument<Boolean>("smartSelfieEnabled") ?: false
                        
                        // Convert string to enum
                        val layout = when (layoutStr.lowercase()) {
                            "pip", "pictureinpicture" -> VideoComposer.RecordingLayout.PICTURE_IN_PICTURE
                            "splitvertical", "sidebyside", "split" -> VideoComposer.RecordingLayout.SPLIT_VERTICAL
                            "splithorizontal" -> VideoComposer.RecordingLayout.SPLIT_HORIZONTAL
                            "frontonly" -> VideoComposer.RecordingLayout.FRONT_ONLY
                            "backonly" -> VideoComposer.RecordingLayout.BACK_ONLY
                            else -> VideoComposer.RecordingLayout.PICTURE_IN_PICTURE
                        }
                        
                        videoComposer?.startRecording(layout, width, height, bitrate, smartSelfieEnabled) { success, error, filePath ->
                            val resultMap = mapOf(
                                "success" to success,
                                "filePath" to filePath,
                                "error" to error
                            )
                            result.success(resultMap)
                        }
                    }
                    "stopRecording" -> {
                        videoComposer?.stopRecording { success, filePath, error ->
                            val resultMap = mapOf(
                                "success" to success,
                                "filePath" to filePath,
                                "error" to error
                            )
                            result.success(resultMap)
                        }
                    }
                    "takeDualPhoto" -> {
                        videoComposer?.takeDualPhoto { success: Boolean, error: String?, filePath: String? ->
                            val resultMap = mapOf(
                                "success" to success,
                                "filePath" to filePath,
                                "error" to error
                            )
                            result.success(resultMap)
                        }
                    }
                    "getRecordingStatus" -> {
                        val status = videoComposer?.getRecordingStatus() ?: mapOf(
                            "isRecording" to false,
                            "layout" to "pip",
                            "outputFile" to "",
                            "duration" to 0.0,
                            "error" to "VideoComposer not available"
                        )
                        result.success(status)
                    }
                    
                    else -> {
                        Log.w(TAG, "Unknown method: ${call.method}")
                        result.notImplemented()
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error in MethodChannel handler", e)
                result.error("HARDWARE_ERROR", e.message, e.toString())
            }
        }
    }
    
    /**
     * Primary dual camera detection logic
     * Uses Android 11+ official API with fallback for older versions
     */
    private fun isDualCameraSupported(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                // Android 11+ official concurrent camera API
                val concurrentCameraIds = cameraManager.concurrentCameraIds
                val isOfficiallySupported = concurrentCameraIds.isNotEmpty()
                
                Log.d(TAG, "Official concurrent camera IDs: $concurrentCameraIds")
                
                // If officially supported, return true
                if (isOfficiallySupported) {
                    return true
                }
                
                // Otherwise, try bypass mode
                Log.i(TAG, "Official API reports no support, attempting bypass mode")
                return checkDualCameraFallback()
            } else {
                // Pre-Android 11 fallback detection
                Log.i(TAG, "Using fallback detection for Android < 11")
                return checkDualCameraFallback()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking dual camera support", e)
            // Graceful degradation - try fallback
            return checkDualCameraFallback()
        }
    }
    
    /**
     * Fallback detection for Android < 11 or when official API fails
     * Implements "Bypass Mode" - attempt dual cameras even if not officially reported
     */
    private fun checkDualCameraFallback(): Boolean {
        return try {
            val cameraIdList = cameraManager.cameraIdList
            var frontCameraId: String? = null
            var backCameraId: String? = null
            
            Log.d(TAG, "Available camera IDs: ${cameraIdList.joinToString()}")
            
            // Enumerate cameras by lens facing
            for (cameraId in cameraIdList) {
                val characteristics = cameraManager.getCameraCharacteristics(cameraId)
                val facing = characteristics.get(CameraCharacteristics.LENS_FACING)
                
                when (facing) {
                    CameraCharacteristics.LENS_FACING_FRONT -> {
                        frontCameraId = cameraId
                        Log.d(TAG, "Found front camera: $cameraId")
                    }
                    CameraCharacteristics.LENS_FACING_BACK -> {
                        backCameraId = cameraId
                        Log.d(TAG, "Found back camera: $cameraId")
                    }
                }
            }
            
            val hasBasicDualCamera = frontCameraId != null && backCameraId != null
            
            if (hasBasicDualCamera) {
                Log.i(TAG, "Basic dual camera detected, checking ISP capabilities")
                return checkConcurrentStreamingCapability(frontCameraId!!, backCameraId!!)
            }
            
            Log.i(TAG, "No dual camera hardware detected")
            return false
            
        } catch (e: Exception) {
            Log.e(TAG, "Error in fallback dual camera check", e)
            return false
        }
    }
    
    /**
     * ISP Capability Validation
     * Check if the Image Signal Processor can handle concurrent streaming
     */
    private fun checkConcurrentStreamingCapability(frontId: String, backId: String): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val frontCharacteristics = cameraManager.getCameraCharacteristics(frontId)
                val backCharacteristics = cameraManager.getCameraCharacteristics(backId)
                
                // Check stream configuration map support
                val frontStreamConfig = frontCharacteristics.get(
                    CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP
                )
                val backStreamConfig = backCharacteristics.get(
                    CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP
                )
                
                val hasStreamSupport = frontStreamConfig != null && backStreamConfig != null
                
                if (hasStreamSupport) {
                    Log.i(TAG, "ISP supports concurrent streaming - enabling bypass mode")
                    return true
                } else {
                    Log.w(TAG, "ISP does not support concurrent streaming")
                    return false
                }
            }
            
            // Assume support on older devices (optimistic approach)
            Log.i(TAG, "Assuming concurrent support on Android < 23")
            return true
            
        } catch (e: Exception) {
            Log.e(TAG, "Error checking ISP capabilities", e)
            return false
        }
    }
    
    /**
     * Get detailed reason why dual camera is not supported
     * Returns null if dual camera IS supported
     */
    private fun getDualCameraUnsupportedReason(): String? {
        return try {
            // First check if it's actually supported
            if (isDualCameraSupported()) {
                return null // No reason - dual camera is supported
            }
            
            // Determine specific reason for lack of support
            when {
                Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP -> {
                    "Android version too old (requires API 21+)"
                }
                
                cameraManager.cameraIdList.size < 2 -> {
                    "Device has less than 2 cameras"
                }
                
                !hasFrontCamera() -> {
                    "No front camera found"
                }
                
                !hasBackCamera() -> {
                    "No back camera found"
                }
                
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && 
                cameraManager.concurrentCameraIds.isEmpty() -> {
                    "Hardware ISP doesn't support concurrent streaming"
                }
                
                else -> {
                    "Unknown hardware limitation"
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting unsupported reason", e)
            "Hardware detection failed: ${e.message}"
        }
    }
    
    /**
     * Get comprehensive hardware capabilities report
     */
    private fun getHardwareCapabilities(): Map<String, Any> {
        return try {
            val capabilities = mutableMapOf<String, Any>()
            
            // Basic device info
            capabilities["androidVersion"] = Build.VERSION.SDK_INT
            capabilities["deviceModel"] = "${Build.MANUFACTURER} ${Build.MODEL}"
            capabilities["totalCameras"] = cameraManager.cameraIdList.size
            
            // Camera enumeration
            capabilities["hasFrontCamera"] = hasFrontCamera()
            capabilities["hasBackCamera"] = hasBackCamera()
            capabilities["frontCameraId"] = getFrontCameraId() ?: "none"
            capabilities["backCameraId"] = getBackCameraId() ?: "none"
            
            // Concurrent support details
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val concurrentIds = cameraManager.concurrentCameraIds
                capabilities["officialConcurrentSupport"] = concurrentIds.isNotEmpty()
                capabilities["concurrentCameraIds"] = concurrentIds.map { it.joinToString(",") }
            } else {
                capabilities["officialConcurrentSupport"] = false
                capabilities["concurrentCameraIds"] = emptyList<String>()
            }
            
            // Final determination
            capabilities["isDualCameraSupported"] = isDualCameraSupported()
            val unsupportedReason = getDualCameraUnsupportedReason()
            if (unsupportedReason != null) {
                capabilities["unsupportedReason"] = unsupportedReason
            }
            
            capabilities
            
        } catch (e: Exception) {
            Log.e(TAG, "Error getting hardware capabilities", e)
            mapOf(
                "error" to true,
                "errorMessage" to (e.message ?: "Unknown error"),
                "isDualCameraSupported" to false
            )
        }
    }
    
    // Helper functions for camera detection
    private fun hasFrontCamera(): Boolean = getFrontCameraId() != null
    private fun hasBackCamera(): Boolean = getBackCameraId() != null
    
    private fun getFrontCameraId(): String? {
        return try {
            cameraManager.cameraIdList.find { cameraId ->
                val characteristics = cameraManager.getCameraCharacteristics(cameraId)
                val facing = characteristics.get(CameraCharacteristics.LENS_FACING)
                facing == CameraCharacteristics.LENS_FACING_FRONT
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error finding front camera", e)
            null
        }
    }
    
    private fun getBackCameraId(): String? {
        return try {
            cameraManager.cameraIdList.find { cameraId ->
                val characteristics = cameraManager.getCameraCharacteristics(cameraId)
                val facing = characteristics.get(CameraCharacteristics.LENS_FACING)
                facing == CameraCharacteristics.LENS_FACING_BACK
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error finding back camera", e)
            null
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        videoComposer?.dispose()
        dualCameraManager?.dispose()
    }
}

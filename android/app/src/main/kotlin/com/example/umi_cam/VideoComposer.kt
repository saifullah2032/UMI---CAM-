package com.example.umi_cam

import android.Manifest
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.*
import android.media.*
import android.media.MediaCodec.BufferInfo
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.HandlerThread
import android.provider.MediaStore
import android.util.Log
import android.view.Surface
import androidx.core.content.ContextCompat
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.BufferOverflowException
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference
import kotlin.math.min

/**
 * VideoComposer - High-performance real-time dual-camera video recording engine
 * 
 * Implements the "Recording Heart" for UMI 海 - CAM with:
 * - MediaCodec H.264 video encoding
 * - AudioRecord AAC audio encoding
 * - Real-time Canvas composition at 30fps
 * - MediaMuxer MP4 output
 * - Synchronized dual-camera frame mixing
 * - High-quality dual photo capture
 */
class VideoComposer(
    private val context: Context,
    private val dualCameraManager: DualCameraManager
) {
    companion object {
        private const val TAG = "VideoComposer"
        
        // Video encoding configuration
        private const val VIDEO_WIDTH = 1920
        private const val VIDEO_HEIGHT = 1080
        private const val VIDEO_BIT_RATE = 8_000_000  // 8 Mbps for high quality
        private const val VIDEO_FRAME_RATE = 30
        private const val VIDEO_I_FRAME_INTERVAL = 1  // 1-second GOP (keyframe every second)
        
        // Audio encoding configuration
        private const val AUDIO_SAMPLE_RATE = 44100
        private const val AUDIO_CHANNEL_COUNT = 1
        private const val AUDIO_BIT_RATE = 128_000  // 128 kbps
        private const val AUDIO_BUFFER_SIZE = 4096
        
        // Layout configuration
        private const val PIP_SIZE_RATIO = 0.25f  // PiP camera size relative to main
        private const val PIP_MARGIN = 20  // Margin from edges in pixels
        
        // Frame composition timing
        private const val COMPOSITION_INTERVAL_MS = 33L  // ~30fps (1000/30)
    }

    // Video encoding components
    private var videoEncoder: MediaCodec? = null
    private var videoEncodingSurface: Surface? = null
    private var videoFormat: MediaFormat? = null
    
    // Audio encoding components
    private var audioEncoder: MediaCodec? = null
    private var audioRecord: AudioRecord? = null
    private var audioFormat: MediaFormat? = null
    
    // Muxing components
    private var mediaMuxer: MediaMuxer? = null
    private var videoTrackIndex = -1
    private var audioTrackIndex = -1
    private var muxerStarted = false
    private var tracksAdded = 0
    private var expectedTracks = 1

    private val videoBufferInfo = BufferInfo()
    private val audioBufferInfo = BufferInfo()
    
    // Canvas composition
    private var compositionCanvas: Canvas? = null
    private var compositionBitmap: Bitmap? = null
    private var paint: Paint? = null
    
    // Threading
    private var compositionThread: HandlerThread? = null
    private var compositionHandler: Handler? = null
    private var audioThread: HandlerThread? = null
    private var audioHandler: Handler? = null
    
    // State management
    private val isRecording = AtomicBoolean(false)
    private val isInitialized = AtomicBoolean(false)
    private var outputFile: File? = null
    private var recordingStartTime = 0L
    private var startTimeNs = 0L
    private var audioStartTimeNs = 0L
    
    // Layout state
    private var currentLayout: RecordingLayout = RecordingLayout.PICTURE_IN_PICTURE
    
    // Camera swap state
    private var camerasSwapped: Boolean = false
    
    // Dynamic PiP coordinates (set from Flutter UI)
    private var pipX: Float = 0f
    private var pipY: Float = 0f  
    private var pipWidth: Float = 0f
    private var pipHeight: Float = 0f
    private var pipCoordinatesSet: Boolean = false
    
    // Smart Selfie configuration
    private var isSmartSelfieEnabled: Boolean = false
    private var enableAudio: Boolean = true
    
    // Smart Crop for 16:9 cinematic frame
    private var enableSmartCrop: Boolean = false
    
    // Frame synchronization
    private val frontFrameRef = AtomicReference<Bitmap?>(null)
    private val backFrameRef = AtomicReference<Bitmap?>(null)
    private var lastCompositionTime = 0L
    
    /**
     * Recording layout modes - matches Flutter CameraLayout enum
     */
    enum class RecordingLayout {
        PICTURE_IN_PICTURE,  // Back camera full-screen, front camera in corner
        SPLIT_VERTICAL,      // Back camera left, front camera right  
        SPLIT_HORIZONTAL,    // Back camera top, front camera bottom
        FRONT_ONLY,          // Front camera only
        BACK_ONLY           // Back camera only
    }

    /**
     * Initialize the video recording pipeline
     */
    fun initialize(callback: (Boolean, String?) -> Unit) {
        Log.d(TAG, "Initializing VideoComposer...")
        
        try {
            // Check audio recording permissions
            if (!hasAudioPermissions()) {
                callback(false, "Audio recording permission not granted")
                return
            }
            
            // Initialize threading
            startBackgroundThreads()
            
            // Initialize paint for canvas operations
            paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                isFilterBitmap = true
                isDither = true
            }
            
            // Create composition bitmap
            compositionBitmap = Bitmap.createBitmap(
                VIDEO_WIDTH,
                VIDEO_HEIGHT,
                Bitmap.Config.ARGB_8888
            )
            compositionCanvas = Canvas(compositionBitmap!!)
            
            isInitialized.set(true)
            
            Log.d(TAG, "VideoComposer initialized successfully")
            callback(true, null)
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize VideoComposer", e)
            cleanup()
            callback(false, "Initialization failed: ${e.message}")
        }
    }

    /**
     * Start recording video with audio and Smart Selfie configuration
     */
    fun startRecording(
        layout: RecordingLayout,
        width: Int = VIDEO_WIDTH,
        height: Int = VIDEO_HEIGHT,
        bitrate: Int = VIDEO_BIT_RATE,
        smartSelfieEnabled: Boolean = false,
        callback: (Boolean, String?, String?) -> Unit
    ) {
        if (!isInitialized.get()) {
            callback(false, "VideoComposer not initialized", null)
            return
        }
        
        if (isRecording.get()) {
            callback(false, "Recording already in progress", null)
            return
        }
        
        Log.d(TAG, "Starting recording with layout: $layout, quality: ${width}x${height}@${bitrate}bps, smartSelfie: $smartSelfieEnabled")
        
        try {
            currentLayout = layout
            isSmartSelfieEnabled = smartSelfieEnabled
            
            // Create output file
            outputFile = createOutputFile()
            
            // Initialize video encoder with dynamic quality settings
            setupVideoEncoder(width, height, bitrate)
            
            // Initialize audio encoder (optional)
            if (enableAudio) {
                setupAudioEncoder()
            }
            
            // Initialize muxer
            setupMediaMuxer()
            
            // Start recording
            isRecording.set(true)
            recordingStartTime = System.currentTimeMillis()
            startTimeNs = System.nanoTime()
            audioStartTimeNs = startTimeNs
            
            // Start composition loop
            startCompositionLoop()
            
            // Start audio recording if enabled
            if (enableAudio) {
                startAudioRecording()
            }
            
            Log.d(TAG, "Recording started successfully")
            Log.d(TAG, "Output file: ${outputFile?.absolutePath}")
            
            callback(true, null, outputFile?.absolutePath)
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start recording", e)
            stopRecordingInternal()
            callback(false, "Recording start failed: ${e.message}", null)
        }
    }

    /**
     * Stop recording and finalize the output file
     */
    fun stopRecording(callback: (Boolean, String?, String?) -> Unit) {
        if (!isRecording.get()) {
            callback(false, "No recording in progress", null)
            return
        }
        
        Log.d(TAG, "Stopping recording...")
        
        try {
            stopRecordingInternal()
            
            val filePath = outputFile?.absolutePath
            val duration = if (recordingStartTime > 0) {
                System.currentTimeMillis() - recordingStartTime
            } else {
                0L
            }
            
            // Ensure file path is always returned, even if null
            if (filePath == null) {
                Log.w(TAG, "Warning: outputFile is null, returning empty path")
            }
            
            Log.d(TAG, "Recording stopped successfully")
            Log.d(TAG, "Duration: ${duration}ms")
            Log.d(TAG, "Output file path: $filePath")
            Log.d(TAG, "Output file exists: ${outputFile?.exists()}")
            
            // CRITICAL: Pass filePath as third parameter (not second)
            // error parameter should be null on success
            callback(true, null, filePath)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping recording", e)
            callback(false, "Stop recording failed: ${e.message}", null)
        }
    }

    /**
     * Capture a high-quality dual photo of the current composition
     */
    fun takeDualPhoto(callback: (Boolean, String?, String?) -> Unit) {
        if (!isInitialized.get()) {
            callback(false, "VideoComposer not initialized", null)
            return
        }
        
        Log.d(TAG, "Taking dual photo...")
        
        compositionHandler?.post {
            try {
                // Create photo composition
                val photoBitmap = createPhotoComposition()
                
                // Save to file
                val photoFile = createPhotoFile()
                savePhoto(photoBitmap, photoFile)
                
                Log.d(TAG, "Dual photo captured: ${photoFile.absolutePath}")
                callback(true, null, photoFile.absolutePath)
                
            } catch (e: Exception) {
                Log.e(TAG, "Failed to take dual photo", e)
                callback(false, "Photo capture failed: ${e.message}", null)
            }
        }
    }

    /**
     * Update the recording layout during recording
     */
    fun setLayout(layout: RecordingLayout) {
        currentLayout = layout
        Log.d(TAG, "Layout changed to: $layout")
    }
    
    /**
     * Update Smart Selfie setting during recording
     */
    fun setSmartSelfieEnabled(enabled: Boolean) {
        isSmartSelfieEnabled = enabled
        Log.d(TAG, "Smart Selfie ${if (enabled) "enabled" else "disabled"}")
    }
    
    /**
     * Enable/disable 16:9 Smart Crop for cinematic effect
     */
    fun setSmartCropEnabled(enabled: Boolean) {
        enableSmartCrop = enabled
        Log.d(TAG, "Smart Crop (16:9 Cinematic) ${if (enabled) "enabled" else "disabled"}")
    }

    fun setAudioEnabled(enabled: Boolean) {
        enableAudio = enabled
        Log.d(TAG, "Audio recording ${if (enabled) "enabled" else "disabled"}")
    }
    
    /**
     * Swap front and back camera roles during recording
     */
    fun swapCameras(swapped: Boolean) {
        camerasSwapped = swapped
        Log.d(TAG, "Cameras ${if (swapped) "swapped" else "normal"} - Primary: ${if (swapped) "Front" else "Back"}")
    }
    
    /**
     * Update PiP window coordinates for dynamic positioning
     */
    fun updatePiPCoordinates(x: Float, y: Float, width: Float, height: Float) {
        // Inputs are normalized [0..1] coordinates from Flutter
        pipX = x.coerceIn(0f, 1f) * VIDEO_WIDTH
        pipY = y.coerceIn(0f, 1f) * VIDEO_HEIGHT
        pipWidth = width.coerceIn(0f, 1f) * VIDEO_WIDTH
        pipHeight = height.coerceIn(0f, 1f) * VIDEO_HEIGHT
        pipCoordinatesSet = true
        
        Log.d(TAG, "PiP coordinates updated: ($pipX, $pipY, $pipWidth, $pipHeight)")
    }
    
    /**
     * Reset PiP coordinates to default positioning
     */
    fun resetPiPCoordinates() {
        pipCoordinatesSet = false
        Log.d(TAG, "PiP coordinates reset to default")
    }

    /**
     * Update camera frames for composition with memory management
     */
    fun updateFrontFrame(frame: Bitmap?) {
        // Recycle previous frame to prevent memory leaks
        val previousFrame = frontFrameRef.getAndSet(frame)
        if (previousFrame != null && !previousFrame.isRecycled && previousFrame != frame) {
            previousFrame.recycle()
        }
    }
    
    fun updateBackFrame(frame: Bitmap?) {
        // Recycle previous frame to prevent memory leaks
        val previousFrame = backFrameRef.getAndSet(frame)
        if (previousFrame != null && !previousFrame.isRecycled && previousFrame != frame) {
            previousFrame.recycle()
        }
    }

    /**
     * Get current recording status
     */
    fun getRecordingStatus(): Map<String, Any> {
        val currentTime = System.currentTimeMillis()
        val duration = if (isRecording.get() && recordingStartTime > 0) {
            currentTime - recordingStartTime
        } else {
            0L
        }
        
        return mapOf(
            "isRecording" to isRecording.get(),
            "isInitialized" to isInitialized.get(),
            "duration" to duration,
            "layout" to currentLayout.name,
            "outputFile" to (outputFile?.absolutePath ?: ""),
            "videoSize" to "${VIDEO_WIDTH}x$VIDEO_HEIGHT",
            "frameRate" to VIDEO_FRAME_RATE,
            "videoBitRate" to VIDEO_BIT_RATE,
            "audioBitRate" to AUDIO_BIT_RATE,
            "enableAudio" to enableAudio
        )
    }

    /**
     * Clean up all resources
     */
    fun dispose() {
        Log.d(TAG, "Disposing VideoComposer...")
        
        stopRecordingInternal()
        cleanup()
        
        isInitialized.set(false)
        Log.d(TAG, "VideoComposer disposed")
    }

    // ============================================================
    // PRIVATE IMPLEMENTATION
    // ============================================================

    private fun hasAudioPermissions(): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun startBackgroundThreads() {
        // Composition thread
        compositionThread = HandlerThread("VideoComposition").apply { start() }
        compositionHandler = Handler(compositionThread!!.looper)
        
        // Audio thread
        audioThread = HandlerThread("AudioRecording").apply { start() }
        audioHandler = Handler(audioThread!!.looper)
    }

    private fun mediaRootDir(): File {
        // CRITICAL FIX: Save to Movies/UMI-CAM directory (not Downloads)
        val mediaDir = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+ (API 29+): Use app-specific directory in Movies with scoped storage
            File(context.getExternalFilesDir(Environment.DIRECTORY_MOVIES), "UMI-CAM")
        } else {
            // Pre-Android 10 (API < 29): Use public Movies directory
            File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES), "UMI-CAM")
        }
        
        // Ensure directory exists
        if (!mediaDir.exists()) {
            mediaDir.mkdirs()
        }
        
        Log.d(TAG, "Media root directory: ${mediaDir.absolutePath}")
        Log.d(TAG, "Using Android API level ${Build.VERSION.SDK_INT} storage method")
        return mediaDir
    }

    private fun createOutputFile(): File {
        val timestamp = System.currentTimeMillis()
        val fileName = "umi_cam_recording_$timestamp.mp4"
        val outputDir = mediaRootDir()
        return File(outputDir, fileName)
    }

    private fun createPhotoFile(): File {
        val timestamp = System.currentTimeMillis()
        val fileName = "umi_cam_photo_$timestamp.jpg"
        val outputDir = mediaRootDir()
        return File(outputDir, fileName)
    }

    private fun setupVideoEncoder(width: Int = VIDEO_WIDTH, height: Int = VIDEO_HEIGHT, bitrate: Int = VIDEO_BIT_RATE) {
        videoFormat = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, bitrate)
            setInteger(MediaFormat.KEY_FRAME_RATE, VIDEO_FRAME_RATE)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, VIDEO_I_FRAME_INTERVAL)
        }
        
        videoEncoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        videoEncoder!!.configure(videoFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        videoEncodingSurface = videoEncoder!!.createInputSurface()
        videoEncoder!!.start()
        
        Log.d(TAG, "Video encoder configured: ${width}x${height} @ ${VIDEO_FRAME_RATE}fps, bitrate: ${bitrate}bps")
    }

    private fun setupAudioEncoder() {
        val minBufferSize = AudioRecord.getMinBufferSize(
            AUDIO_SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        
        if (minBufferSize == AudioRecord.ERROR || minBufferSize == AudioRecord.ERROR_BAD_VALUE) {
            Log.e(TAG, "Invalid audio buffer size calculation")
            throw IllegalStateException("Cannot determine minimum buffer size for audio")
        }
        
        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            AUDIO_SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            minBufferSize * 4  // CRITICAL: 4x multiplier prevents BufferOverflowException
        )
        
        audioFormat = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, AUDIO_SAMPLE_RATE, AUDIO_CHANNEL_COUNT).apply {
            setInteger(MediaFormat.KEY_BIT_RATE, AUDIO_BIT_RATE)
            setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, minBufferSize * 2)  // CRITICAL: 2x multiplier for codec input size
        }
        
        audioEncoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
        audioEncoder!!.configure(audioFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        audioEncoder!!.start()
        
        Log.d(TAG, "Audio encoder configured: ${AUDIO_SAMPLE_RATE}Hz mono @ ${AUDIO_BIT_RATE}bps")
        Log.d(TAG, "AudioRecord buffer size: ${minBufferSize * 4} bytes (minBufferSize: $minBufferSize, multiplier: 4x for overflow prevention)")
        Log.d(TAG, "KEY_MAX_INPUT_SIZE: ${minBufferSize * 2} bytes (2x safety margin)")
    }

    // MediaStore publishing intentionally disabled while using unified app-local storage flow.

    private fun setupMediaMuxer() {
        mediaMuxer = MediaMuxer(outputFile!!.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

        tracksAdded = 0
        expectedTracks = if (enableAudio && audioEncoder != null) 2 else 1

        Log.d(TAG, "MediaMuxer created, waiting for encoder output formats (expectedTracks=$expectedTracks)")
    }

    private fun startCompositionLoop() {
        compositionHandler?.post(object : Runnable {
            override fun run() {
                if (isRecording.get()) {
                    try {
                        composeFrame()
                        
                        // Schedule next composition
                        val nextTime = lastCompositionTime + COMPOSITION_INTERVAL_MS
                        val delay = maxOf(0, nextTime - System.currentTimeMillis())
                        compositionHandler?.postDelayed(this, delay)
                        
                    } catch (e: Exception) {
                        Log.e(TAG, "Error in composition loop", e)
                    }
                }
            }
        })
        
        Log.d(TAG, "Composition loop started at ${VIDEO_FRAME_RATE}fps")
    }

    private fun composeFrame() {
        val currentTime = System.currentTimeMillis()
        
        // Skip frame if too soon (frame rate limiting)
        if (currentTime - lastCompositionTime < COMPOSITION_INTERVAL_MS) {
            return
        }
        
        lastCompositionTime = currentTime
        
        val latestFront = dualCameraManager.getCurrentFrontFrame()
        if (latestFront != null) {
            updateFrontFrame(latestFront.copy(latestFront.config ?: Bitmap.Config.ARGB_8888, false))
        }

        val latestBack = dualCameraManager.getCurrentBackFrame()
        if (latestBack != null) {
            updateBackFrame(latestBack.copy(latestBack.config ?: Bitmap.Config.ARGB_8888, false))
        }

        val frontFrame = frontFrameRef.get()
        val backFrame = backFrameRef.get()
        
        // Clear canvas
        compositionCanvas?.drawColor(Color.BLACK, PorterDuff.Mode.CLEAR)
        
        when (currentLayout) {
            RecordingLayout.PICTURE_IN_PICTURE -> {
                drawPictureInPicture(frontFrame, backFrame)
            }
            RecordingLayout.SPLIT_VERTICAL -> {
                drawSplitVertical(frontFrame, backFrame)
            }
            RecordingLayout.SPLIT_HORIZONTAL -> {
                drawSplitHorizontal(frontFrame, backFrame)
            }
            RecordingLayout.FRONT_ONLY -> {
                drawSingleCamera(frontFrame, true)
            }
            RecordingLayout.BACK_ONLY -> {
                drawSingleCamera(backFrame, false)
            }
        }
        
        // Draw cinematic frame overlay if smart crop is enabled
        if (enableSmartCrop && currentLayout == RecordingLayout.FRONT_ONLY) {
            drawCinematicFrameOverlay()
        }
        
        // Draw to encoder surface and drain encoded output
        drawToEncoderSurface()
        drainVideoEncoder(false)
    }

    private fun drawPictureInPicture(frontFrame: Bitmap?, backFrame: Bitmap?) {
        // Determine which frames to use as primary/secondary based on swap state
        val primaryFrame = if (camerasSwapped) frontFrame else backFrame
        val secondaryFrame = if (camerasSwapped) backFrame else frontFrame
        
        // Draw primary camera as main (full screen)
        primaryFrame?.let { frame ->
            val destRect = Rect(0, 0, VIDEO_WIDTH, VIDEO_HEIGHT)
            val isFrontMain = camerasSwapped
            val sourceRect = sourceRectForFrame(frame, isFrontMain)
            compositionCanvas?.drawBitmap(frame, sourceRect, destRect, paint)
        }
        
        // Draw secondary camera as PiP (overlay)
        secondaryFrame?.let { frame ->
            val pipRect = if (pipCoordinatesSet) {
                // Use dynamic coordinates from Flutter UI
                Rect(
                    pipX.toInt(),
                    pipY.toInt(), 
                    (pipX + pipWidth).toInt(),
                    (pipY + pipHeight).toInt()
                )
            } else {
                // Use default coordinates
                val defaultPipWidth = (VIDEO_WIDTH * PIP_SIZE_RATIO).toInt()
                val defaultPipHeight = (VIDEO_HEIGHT * PIP_SIZE_RATIO).toInt()
                val defaultPipX = VIDEO_WIDTH - defaultPipWidth - PIP_MARGIN
                val defaultPipY = PIP_MARGIN
                
                Rect(defaultPipX, defaultPipY, defaultPipX + defaultPipWidth, defaultPipY + defaultPipHeight)
            }
            
            // Apply Smart Selfie 16:9 crop if enabled (only for front camera)
            val isFrontPip = !camerasSwapped
            val sourceRect = sourceRectForFrame(frame, isFrontPip)
            
            // Draw border
            val borderPaint = Paint().apply {
                color = Color.WHITE
                style = Paint.Style.STROKE
                strokeWidth = 4f
            }
            compositionCanvas?.drawRect(pipRect, borderPaint)
            
            // Draw PiP frame
            compositionCanvas?.drawBitmap(frame, sourceRect, pipRect, paint)
        }
    }
    
    /**
     * Draw vertical split layout (Back left, Front right)
     */
    private fun drawSplitVertical(frontFrame: Bitmap?, backFrame: Bitmap?) {
        val leftRect = Rect(0, 0, VIDEO_WIDTH / 2, VIDEO_HEIGHT)
        val rightRect = Rect(VIDEO_WIDTH / 2, 0, VIDEO_WIDTH, VIDEO_HEIGHT)
        
        // Determine which frames go where based on swap state
        val leftFrame = if (camerasSwapped) frontFrame else backFrame
        val rightFrame = if (camerasSwapped) backFrame else frontFrame
        
        // Draw left camera
        leftFrame?.let { frame ->
            val isFrontLeft = camerasSwapped
            val sourceRect = sourceRectForFrame(frame, isFrontLeft)
            compositionCanvas?.drawBitmap(frame, sourceRect, leftRect, paint)
        }
        
        // Draw right camera  
        rightFrame?.let { frame ->
            val isFrontRight = !camerasSwapped
            val sourceRect = sourceRectForFrame(frame, isFrontRight)
            compositionCanvas?.drawBitmap(frame, sourceRect, rightRect, paint)
        }
        
        // Draw center divider line
        val dividerPaint = Paint().apply {
            color = Color.WHITE
            style = Paint.Style.STROKE
            strokeWidth = 4f
        }
        compositionCanvas?.drawLine(
            (VIDEO_WIDTH / 2).toFloat(), 0f,
            (VIDEO_WIDTH / 2).toFloat(), VIDEO_HEIGHT.toFloat(),
            dividerPaint
        )
    }
    
    /**
     * Draw horizontal split layout (Back top, Front bottom)
     */
    private fun drawSplitHorizontal(frontFrame: Bitmap?, backFrame: Bitmap?) {
        val topRect = Rect(0, 0, VIDEO_WIDTH, VIDEO_HEIGHT / 2)
        val bottomRect = Rect(0, VIDEO_HEIGHT / 2, VIDEO_WIDTH, VIDEO_HEIGHT)
        
        // Determine which frames go where based on swap state
        val topFrame = if (camerasSwapped) frontFrame else backFrame
        val bottomFrame = if (camerasSwapped) backFrame else frontFrame
        
        // Draw top camera
        topFrame?.let { frame ->
            val isFrontTop = camerasSwapped
            val sourceRect = sourceRectForFrame(frame, isFrontTop)
            compositionCanvas?.drawBitmap(frame, sourceRect, topRect, paint)
        }
        
        // Draw bottom camera
        bottomFrame?.let { frame ->
            val isFrontBottom = !camerasSwapped
            val sourceRect = sourceRectForFrame(frame, isFrontBottom)
            compositionCanvas?.drawBitmap(frame, sourceRect, bottomRect, paint)
        }
        
        // Draw center divider line  
        val dividerPaint = Paint().apply {
            color = Color.WHITE
            style = Paint.Style.STROKE
            strokeWidth = 4f
        }
        compositionCanvas?.drawLine(
            0f, (VIDEO_HEIGHT / 2).toFloat(),
            VIDEO_WIDTH.toFloat(), (VIDEO_HEIGHT / 2).toFloat(),
            dividerPaint
        )
    }
    
    /**
     * Calculate Smart Crop for 16:9 cinematic effect with 1.2x zoom
     * Crops the top and bottom of the frame to maintain 16:9 aspect ratio
     * Applies 1.2x zoom to fill the horizontal width
     */
    private fun calculateSmartCrop16to9(frame: Bitmap): Rect {
        val frameWidth = frame.width.toFloat()
        val frameHeight = frame.height.toFloat()
        val targetAspectRatio = 16f / 9f  // 1.778
        val zoomFactor = 1.2f
        
        // Calculate the height needed for 16:9 aspect ratio
        val requiredHeight = frameWidth / targetAspectRatio
        
        // Apply zoom - this increases the crop area
        val zoomedHeight = requiredHeight / zoomFactor
        val zoomedWidth = frameWidth / zoomFactor
        
        // Center crop both horizontally and vertically
        val cropX = ((frameWidth - zoomedWidth) / 2f).toInt()
        val cropY = ((frameHeight - zoomedHeight) / 2f).toInt()
        
        val cropWidth = zoomedWidth.toInt()
        val cropHeight = zoomedHeight.toInt()
        
        Log.d(TAG, "16:9 Crop: source=${frame.width}x${frame.height}, crop=(${cropX},${cropY},${cropWidth}x${cropHeight}), zoom=$zoomFactor")
        
        return Rect(cropX, cropY, cropX + cropWidth, cropY + cropHeight)
    }

    /**
     * Calculate Smart Selfie 16:9 center crop from 4:3 frame
     * Crops the top and bottom to maintain 16:9 aspect ratio
     */
    private fun calculateSmartSelfieCrop(frame: Bitmap): Rect {
        val frameWidth = frame.width
        val frameHeight = frame.height
        val targetAspectRatio = 16f / 9f
        val srcAspect = frameWidth.toFloat() / frameHeight.toFloat()

        return if (srcAspect > targetAspectRatio) {
            val cropH = frameHeight
            val cropW = (frameHeight * targetAspectRatio).toInt()
            val cropX = (frameWidth - cropW) / 2
            Rect(cropX, 0, cropX + cropW, cropH)
        } else {
            val cropW = frameWidth
            val cropH = (frameWidth / targetAspectRatio).toInt()
            val cropY = (frameHeight - cropH) / 2
            Rect(0, cropY, cropW, cropY + cropH)
        }
    }

    private fun sourceRectForFrame(frame: Bitmap, isFrontFrame: Boolean): Rect? {
        // Apply smart crop if enabled for front camera
        if (enableSmartCrop && isFrontFrame) {
            return calculateSmartCrop16to9(frame)
        }
        // Apply smart selfie crop if enabled for front camera
        if (isSmartSelfieEnabled && isFrontFrame) {
            return calculateSmartSelfieCrop(frame)
        }
        return null
    }

    private fun drawSingleCamera(frame: Bitmap?, isFront: Boolean) {
        frame?.let {
            val destRect = Rect(0, 0, VIDEO_WIDTH, VIDEO_HEIGHT)
            val sourceRect = sourceRectForFrame(it, isFront)
            compositionCanvas?.drawBitmap(it, sourceRect, destRect, paint)
        }
    }
    
    /**
     * Draw the cinematic frame overlay to show the user what's being recorded
     * Shows the 16:9 crop area with Neo-Brutalist styling
     */
    private fun drawCinematicFrameOverlay() {
        // 16:9 aspect ratio in 1920x1080 output
        val cinWidth = VIDEO_WIDTH
        val cinHeight = (VIDEO_WIDTH * 9f / 16f).toInt()
        val cinY = (VIDEO_HEIGHT - cinHeight) / 2
        
        // Draw semi-transparent mask for areas outside 16:9 frame
        val maskPaint = Paint().apply {
            color = Color.argb(200, 0, 0, 0)
            style = Paint.Style.FILL
        }
        
        // Top mask
        compositionCanvas?.drawRect(0f, 0f, VIDEO_WIDTH.toFloat(), cinY.toFloat(), maskPaint)
        // Bottom mask
        compositionCanvas?.drawRect(0f, (cinY + cinHeight).toFloat(), VIDEO_WIDTH.toFloat(), VIDEO_HEIGHT.toFloat(), maskPaint)
        
        // Draw frame border (Neo-Brutalist style)
        val borderPaint = Paint().apply {
            color = Color.YELLOW
            style = Paint.Style.STROKE
            strokeWidth = 3f
        }
        compositionCanvas?.drawRect(0f, cinY.toFloat(), VIDEO_WIDTH.toFloat(), (cinY + cinHeight).toFloat(), borderPaint)
        
        // Draw corner accents (Neo-Brutalist touch)
        val cornerSize = 30
        val cornerPaint = Paint().apply {
            color = Color.YELLOW
            style = Paint.Style.STROKE
            strokeWidth = 4f
        }
        
        // Top-left corner
        compositionCanvas?.drawLine(0f, cinY.toFloat(), cornerSize.toFloat(), cinY.toFloat(), cornerPaint)
        compositionCanvas?.drawLine(0f, cinY.toFloat(), 0f, (cinY + cornerSize).toFloat(), cornerPaint)
        
        // Top-right corner
        compositionCanvas?.drawLine((VIDEO_WIDTH - cornerSize).toFloat(), cinY.toFloat(), VIDEO_WIDTH.toFloat(), cinY.toFloat(), cornerPaint)
        compositionCanvas?.drawLine(VIDEO_WIDTH.toFloat(), cinY.toFloat(), VIDEO_WIDTH.toFloat(), (cinY + cornerSize).toFloat(), cornerPaint)
        
        // Bottom-left corner
        compositionCanvas?.drawLine(0f, (cinY + cinHeight - cornerSize).toFloat(), 0f, (cinY + cinHeight).toFloat(), cornerPaint)
        compositionCanvas?.drawLine(0f, (cinY + cinHeight).toFloat(), cornerSize.toFloat(), (cinY + cinHeight).toFloat(), cornerPaint)
        
        // Bottom-right corner
        compositionCanvas?.drawLine(VIDEO_WIDTH.toFloat(), (cinY + cinHeight - cornerSize).toFloat(), VIDEO_WIDTH.toFloat(), (cinY + cinHeight).toFloat(), cornerPaint)
        compositionCanvas?.drawLine((VIDEO_WIDTH - cornerSize).toFloat(), (cinY + cinHeight).toFloat(), VIDEO_WIDTH.toFloat(), (cinY + cinHeight).toFloat(), cornerPaint)
    }

    private fun drawToEncoderSurface() {
        val inputSurface = videoEncodingSurface ?: return
        val composed = compositionBitmap ?: return
        val canvas = inputSurface.lockCanvas(null)
        try {
            canvas.drawColor(Color.BLACK)
            val dest = Rect(0, 0, canvas.width, canvas.height)
            canvas.drawBitmap(composed, null, dest, paint)
        } finally {
            inputSurface.unlockCanvasAndPost(canvas)
        }
    }

    private fun startAudioRecording() {
        audioHandler?.post {
            try {
                audioRecord?.startRecording()
                
                val audioBuffer = ByteArray(AUDIO_BUFFER_SIZE)
                
                while (isRecording.get()) {
                    val bytesRead = audioRecord?.read(audioBuffer, 0, audioBuffer.size) ?: -1
                    
                    if (bytesRead > 0) {
                        // Encode audio data
                        encodeAudioData(audioBuffer, bytesRead)
                    }
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "Error in audio recording", e)
            }
        }
        
        Log.d(TAG, "Audio recording started")
    }

    private fun encodeAudioData(data: ByteArray, length: Int) {
        val encoder = audioEncoder ?: return

        try {
            var offset = 0

            while (offset < length && isRecording.get()) {
                val inputIndex = encoder.dequeueInputBuffer(10_000)
                if (inputIndex < 0) {
                    drainAudioEncoder(false)
                    continue
                }

                val inputBuffer = encoder.getInputBuffer(inputIndex)
                if (inputBuffer == null) {
                    encoder.queueInputBuffer(inputIndex, 0, 0, (System.nanoTime() - audioStartTimeNs) / 1000L, 0)
                    continue
                }

                inputBuffer.clear()
                val writable = inputBuffer.remaining()
                val toWrite = minOf(writable, length - offset)

                if (toWrite <= 0) {
                    encoder.queueInputBuffer(inputIndex, 0, 0, (System.nanoTime() - audioStartTimeNs) / 1000L, 0)
                    break
                }

                inputBuffer.put(data, offset, toWrite)
                val ptsUs = (System.nanoTime() - audioStartTimeNs) / 1000L
                encoder.queueInputBuffer(inputIndex, 0, toWrite, ptsUs, 0)
                offset += toWrite

                drainAudioEncoder(false)
            }

            drainAudioEncoder(false)
        } catch (e: BufferOverflowException) {
            val probeIndex = encoder.dequeueInputBuffer(0)
            val cap = if (probeIndex >= 0) encoder.getInputBuffer(probeIndex)?.capacity() ?: -1 else -1
            Log.e(TAG, "Audio BufferOverflowException: dataLength=$length, codecInputCapacity=$cap", e)
        } catch (e: Exception) {
            Log.e(TAG, "Audio encode failure", e)
        }
    }

    private fun maybeStartMuxer() {
        if (!muxerStarted && tracksAdded >= expectedTracks) {
            mediaMuxer?.start()
            muxerStarted = true
            Log.d(TAG, "MediaMuxer started (videoTrack=$videoTrackIndex, audioTrack=$audioTrackIndex)")
        }
    }

    private fun drainVideoEncoder(endOfStream: Boolean) {
        val encoder = videoEncoder ?: return
        if (endOfStream) {
            encoder.signalEndOfInputStream()
        }

        while (true) {
            val outputIndex = encoder.dequeueOutputBuffer(videoBufferInfo, 0)
            when {
                outputIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    if (!endOfStream) return
                }
                outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    if (videoTrackIndex == -1) {
                        videoTrackIndex = mediaMuxer!!.addTrack(encoder.outputFormat)
                        tracksAdded++
                        maybeStartMuxer()
                    }
                }
                outputIndex >= 0 -> {
                    val encodedData = encoder.getOutputBuffer(outputIndex) ?: run {
                        encoder.releaseOutputBuffer(outputIndex, false)
                        continue
                    }

                    if ((videoBufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) != 0) {
                        videoBufferInfo.size = 0
                    }

                    if (videoBufferInfo.size > 0 && muxerStarted && videoTrackIndex >= 0) {
                        encodedData.position(videoBufferInfo.offset)
                        encodedData.limit(videoBufferInfo.offset + videoBufferInfo.size)
                        if (videoBufferInfo.presentationTimeUs <= 0L) {
                            videoBufferInfo.presentationTimeUs = (System.nanoTime() - startTimeNs) / 1000L
                        }
                        mediaMuxer?.writeSampleData(videoTrackIndex, encodedData, videoBufferInfo)
                    }

                    val eos = (videoBufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0
                    encoder.releaseOutputBuffer(outputIndex, false)
                    if (eos) return
                }
            }
        }
    }

    private fun drainAudioEncoder(endOfStream: Boolean) {
        val encoder = audioEncoder ?: return

        if (endOfStream) {
            val inputIndex = encoder.dequeueInputBuffer(10_000)
            if (inputIndex >= 0) {
                encoder.queueInputBuffer(inputIndex, 0, 0, (System.nanoTime() - audioStartTimeNs) / 1000L, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
            }
        }

        while (true) {
            val outputIndex = encoder.dequeueOutputBuffer(audioBufferInfo, 0)
            when {
                outputIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    if (!endOfStream) return
                }
                outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    if (audioTrackIndex == -1) {
                        audioTrackIndex = mediaMuxer!!.addTrack(encoder.outputFormat)
                        tracksAdded++
                        maybeStartMuxer()
                    }
                }
                outputIndex >= 0 -> {
                    val encodedData = encoder.getOutputBuffer(outputIndex) ?: run {
                        encoder.releaseOutputBuffer(outputIndex, false)
                        continue
                    }

                    if ((audioBufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) != 0) {
                        audioBufferInfo.size = 0
                    }

                    if (audioBufferInfo.size > 0 && muxerStarted && audioTrackIndex >= 0) {
                        encodedData.position(audioBufferInfo.offset)
                        encodedData.limit(audioBufferInfo.offset + audioBufferInfo.size)
                        if (audioBufferInfo.presentationTimeUs <= 0L) {
                            audioBufferInfo.presentationTimeUs = (System.nanoTime() - audioStartTimeNs) / 1000L
                        }
                        mediaMuxer?.writeSampleData(audioTrackIndex, encodedData, audioBufferInfo)
                    }

                    val eos = (audioBufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0
                    encoder.releaseOutputBuffer(outputIndex, false)
                    if (eos) return
                }
            }
        }
    }

    private fun createPhotoComposition(): Bitmap {
        val photoBitmap = Bitmap.createBitmap(
            VIDEO_WIDTH,
            VIDEO_HEIGHT,
            Bitmap.Config.ARGB_8888
        )
        
        val photoCanvas = Canvas(photoBitmap)
        
        val frontFrame = frontFrameRef.get()
        val backFrame = backFrameRef.get()
        
        // Use current layout for photo composition
        when (currentLayout) {
            RecordingLayout.PICTURE_IN_PICTURE -> {
                // Same logic as video composition but for high-quality photo
                backFrame?.let { frame ->
                    val destRect = Rect(0, 0, VIDEO_WIDTH, VIDEO_HEIGHT)
                    photoCanvas.drawBitmap(frame, null, destRect, paint)
                }
                
                frontFrame?.let { frame ->
                    val pipWidth = (VIDEO_WIDTH * PIP_SIZE_RATIO).toInt()
                    val pipHeight = (VIDEO_HEIGHT * PIP_SIZE_RATIO).toInt()
                    
                    val pipX = VIDEO_WIDTH - pipWidth - PIP_MARGIN
                    val pipY = PIP_MARGIN
                    
                    val pipRect = Rect(pipX, pipY, pipX + pipWidth, pipY + pipHeight)
                    photoCanvas.drawBitmap(frame, null, pipRect, paint)
                }
            }
            // Implement other layouts...
            else -> {
                backFrame?.let { frame ->
                    val destRect = Rect(0, 0, VIDEO_WIDTH, VIDEO_HEIGHT)
                    photoCanvas.drawBitmap(frame, null, destRect, paint)
                }
            }
        }
        
        return photoBitmap
    }

    private fun savePhoto(bitmap: Bitmap, file: File) {
        FileOutputStream(file).use { out ->
            bitmap.compress(Bitmap.CompressFormat.JPEG, 95, out)
        }
    }

    private fun stopRecordingInternal() {
        isRecording.set(false)
        
        try {
            // Stop audio recording
            if (enableAudio) {
                audioRecord?.stop()
            }

            // Final drains
            if (enableAudio) {
                drainAudioEncoder(true)
            }
            drainVideoEncoder(true)
            
            // Stop encoders
            videoEncoder?.stop()
            if (enableAudio) {
                audioEncoder?.stop()
            }
            
            Log.d(TAG, "All encoders stopped, proceeding to muxer shutdown...")
            
            // Stop muxer ONLY after all encoders have finished
            if (muxerStarted) {
                try {
                    mediaMuxer?.stop()
                    muxerStarted = false
                    Log.d(TAG, "MediaMuxer stopped successfully")
                } catch (e: Exception) {
                    Log.e(TAG, "Error stopping muxer", e)
                }
            }
            
            Log.d(TAG, "Recording components stopped")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping recording components", e)
        }
        
        // Release resources
         releaseEncoders()
         
         // Save video to MediaStore DCIM/UMI-CAM for Gallery visibility
         saveVideoToGallery()
         
         // Trigger media scanner to update Gallery
         triggerMediaScan()
    }
    
    /**
     * Save the recorded video to MediaStore DCIM/UMI-CAM directory
     * This makes the video immediately visible in the device's Gallery/Photos app
     */
    private fun saveVideoToGallery() {
        val sourceFile = outputFile ?: return
        
        if (!sourceFile.exists()) {
            Log.e(TAG, "Source video file does not exist: ${sourceFile.absolutePath}")
            return
        }
        
        try {
            val timestamp = System.currentTimeMillis()
            val displayName = "VID_${timestamp}_dual.mp4"
            
            // Create MediaStore entry for DCIM/UMI-CAM
            val values = ContentValues().apply {
                put(MediaStore.Video.Media.DISPLAY_NAME, displayName)
                put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
                put(MediaStore.Video.Media.RELATIVE_PATH, "DCIM/UMI-CAM")
                put(MediaStore.Video.Media.DATE_ADDED, System.currentTimeMillis() / 1000)
                put(MediaStore.Video.Media.DATE_MODIFIED, System.currentTimeMillis() / 1000)
            }
            
            // Insert into MediaStore and get Uri
            val uri = context.contentResolver.insert(
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                values
            )
            
            if (uri == null) {
                Log.e(TAG, "Failed to create MediaStore entry for video")
                return
            }
            
            // Copy video data to MediaStore location via Uri
            context.contentResolver.openOutputStream(uri)?.use { outputStream ->
                sourceFile.inputStream().use { inputStream ->
                    inputStream.copyTo(outputStream)
                }
            }
            
            Log.d(TAG, "Video saved to MediaStore: $displayName")
            Log.d(TAG, "Uri: $uri")
            Log.d(TAG, "File will appear in DCIM/UMI-CAM")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error saving video to MediaStore", e)
        }
    }
    
    /**
     * Trigger media scanner to make the file immediately visible in Photos app
     */
    private fun triggerMediaScan() {
        val filePath = outputFile?.absolutePath ?: return
        
        try {
            MediaScannerConnection.scanFile(
                context,
                arrayOf(filePath),
                arrayOf("video/mp4"),
                null
            )
            Log.d(TAG, "Media scanner triggered for: $filePath")
        } catch (e: Exception) {
            Log.e(TAG, "Error triggering media scanner", e)
        }
    }

    private fun releaseEncoders() {
        try {
            videoEncoder?.release()
            audioEncoder?.release()
            mediaMuxer?.release()
            audioRecord?.release()
            videoEncodingSurface?.release()
            
            videoEncoder = null
            audioEncoder = null
            mediaMuxer = null
            audioRecord = null
            videoEncodingSurface = null
            videoTrackIndex = -1
            audioTrackIndex = -1
            
            Log.d(TAG, "Encoders released")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing encoders", e)
        }
    }

    private fun cleanup() {
        try {
            // Clean up frame references and recycle bitmaps
            val frontFrame = frontFrameRef.getAndSet(null)
            val backFrame = backFrameRef.getAndSet(null)
            
            frontFrame?.let {
                if (!it.isRecycled) {
                    it.recycle()
                    Log.d(TAG, "Recycled front frame bitmap")
                }
            }
            
            backFrame?.let {
                if (!it.isRecycled) {
                    it.recycle()
                    Log.d(TAG, "Recycled back frame bitmap")
                }
            }
            
            compositionThread?.quitSafely()
            audioThread?.quitSafely()
            
            compositionThread?.join()
            audioThread?.join()
            
            compositionThread = null
            audioThread = null
            compositionHandler = null
            audioHandler = null
            
            compositionBitmap?.let {
                if (!it.isRecycled) {
                    it.recycle()
                    Log.d(TAG, "Recycled composition bitmap")
                }
            }
            compositionBitmap = null
            compositionCanvas = null
            paint = null
            
            Log.d(TAG, "Cleanup completed - all bitmaps recycled")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error during cleanup", e)
        }
    }
}

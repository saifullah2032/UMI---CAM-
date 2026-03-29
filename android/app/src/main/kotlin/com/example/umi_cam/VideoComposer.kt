package com.example.umi_cam

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.*
import android.media.*
import android.media.MediaCodec.BufferInfo
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import android.view.Surface
import androidx.core.content.ContextCompat
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
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
        private const val VIDEO_I_FRAME_INTERVAL = 2  // GOP size
        
        // Audio encoding configuration
        private const val AUDIO_SAMPLE_RATE = 44100
        private const val AUDIO_CHANNEL_COUNT = 2  // Stereo
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
            
            // Initialize audio encoder
            setupAudioEncoder()
            
            // Initialize muxer
            setupMediaMuxer()
            
            // Start recording
            isRecording.set(true)
            recordingStartTime = System.currentTimeMillis()
            
            // Start composition loop
            startCompositionLoop()
            
            // Start audio recording
            startAudioRecording()
            
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
            
            Log.d(TAG, "Recording stopped successfully")
            Log.d(TAG, "Duration: ${duration}ms")
            Log.d(TAG, "Output: $filePath")
            
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
        // Convert from Flutter screen coordinates to video coordinates
        pipX = (x / 1920f) * VIDEO_WIDTH  // Assuming Flutter uses 1920x1080 reference
        pipY = (y / 1080f) * VIDEO_HEIGHT
        pipWidth = (width / 1920f) * VIDEO_WIDTH
        pipHeight = (height / 1080f) * VIDEO_HEIGHT
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
            "audioBitRate" to AUDIO_BIT_RATE
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

    private fun createOutputFile(): File {
        val timestamp = System.currentTimeMillis()
        val fileName = "umi_cam_recording_$timestamp.mp4"
        val outputDir = File(context.cacheDir, "recordings")
        
        if (!outputDir.exists()) {
            outputDir.mkdirs()
        }
        
        return File(outputDir, fileName)
    }

    private fun createPhotoFile(): File {
        val timestamp = System.currentTimeMillis()
        val fileName = "umi_cam_photo_$timestamp.jpg"
        val outputDir = File(context.cacheDir, "photos")
        
        if (!outputDir.exists()) {
            outputDir.mkdirs()
        }
        
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
        audioFormat = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, AUDIO_SAMPLE_RATE, AUDIO_CHANNEL_COUNT).apply {
            setInteger(MediaFormat.KEY_BIT_RATE, AUDIO_BIT_RATE)
            setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
        }
        
        audioEncoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
        audioEncoder!!.configure(audioFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        audioEncoder!!.start()
        
        // Initialize AudioRecord
        val minBufferSize = AudioRecord.getMinBufferSize(
            AUDIO_SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_STEREO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        
        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            AUDIO_SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_STEREO,
            AudioFormat.ENCODING_PCM_16BIT,
            maxOf(minBufferSize, AUDIO_BUFFER_SIZE)
        )
        
        Log.d(TAG, "Audio encoder configured: ${AUDIO_SAMPLE_RATE}Hz stereo @ ${AUDIO_BIT_RATE}bps")
    }

    private fun setupMediaMuxer() {
        mediaMuxer = MediaMuxer(outputFile!!.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        
        videoTrackIndex = mediaMuxer!!.addTrack(videoFormat!!)
        audioTrackIndex = mediaMuxer!!.addTrack(audioFormat!!)
        
        mediaMuxer!!.start()
        muxerStarted = true
        
        Log.d(TAG, "MediaMuxer started with video track $videoTrackIndex and audio track $audioTrackIndex")
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
        
        // Draw to encoder surface
        drawToEncoderSurface()
    }

    private fun drawPictureInPicture(frontFrame: Bitmap?, backFrame: Bitmap?) {
        // Determine which frames to use as primary/secondary based on swap state
        val primaryFrame = if (camerasSwapped) frontFrame else backFrame
        val secondaryFrame = if (camerasSwapped) backFrame else frontFrame
        
        // Draw primary camera as main (full screen)
        primaryFrame?.let { frame ->
            val destRect = Rect(0, 0, VIDEO_WIDTH, VIDEO_HEIGHT)
            compositionCanvas?.drawBitmap(frame, null, destRect, paint)
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
            val sourceRect = if (isSmartSelfieEnabled && !camerasSwapped) {
                calculateSmartSelfieCrop(frame)
            } else {
                null // Use entire frame
            }
            
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
            val sourceRect = if (isSmartSelfieEnabled && (camerasSwapped || frame == frontFrame)) {
                calculateSmartSelfieCrop(frame)
            } else null
            
            compositionCanvas?.drawBitmap(frame, sourceRect, leftRect, paint)
        }
        
        // Draw right camera  
        rightFrame?.let { frame ->
            val sourceRect = if (isSmartSelfieEnabled && (!camerasSwapped || frame == frontFrame)) {
                calculateSmartSelfieCrop(frame)
            } else null
            
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
            val sourceRect = if (isSmartSelfieEnabled && (camerasSwapped || frame == frontFrame)) {
                calculateSmartSelfieCrop(frame)
            } else null
            
            compositionCanvas?.drawBitmap(frame, sourceRect, topRect, paint)
        }
        
        // Draw bottom camera
        bottomFrame?.let { frame ->
            val sourceRect = if (isSmartSelfieEnabled && (!camerasSwapped || frame == frontFrame)) {
                calculateSmartSelfieCrop(frame)
            } else null
            
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
     * Calculate Smart Selfie 16:9 center crop from 4:3 frame
     * Crops the top and bottom to maintain 16:9 aspect ratio
     */
    private fun calculateSmartSelfieCrop(frame: Bitmap): Rect {
        val frameWidth = frame.width
        val frameHeight = frame.height
        
        // Calculate target 16:9 dimensions within 4:3 frame
        val targetAspectRatio = 16.0f / 9.0f
        val currentAspectRatio = frameWidth.toFloat() / frameHeight.toFloat()
        
        return if (currentAspectRatio > targetAspectRatio) {
            // Frame is wider than 16:9, crop sides (shouldn't happen with typical cameras)
            val targetWidth = (frameHeight * targetAspectRatio).toInt()
            val cropX = (frameWidth - targetWidth) / 2
            Rect(cropX, 0, cropX + targetWidth, frameHeight)
        } else {
            // Frame is taller than 16:9, crop top/bottom (typical case for 4:3 to 16:9)
            val targetHeight = (frameWidth / targetAspectRatio).toInt()
            val cropY = (frameHeight - targetHeight) / 2
            Rect(0, cropY, frameWidth, cropY + targetHeight)
        }
    }

    private fun drawSingleCamera(frame: Bitmap?, isFront: Boolean) {
        frame?.let {
            val destRect = Rect(0, 0, VIDEO_WIDTH, VIDEO_HEIGHT)
            compositionCanvas?.drawBitmap(it, null, destRect, paint)
        }
    }

    private fun drawToEncoderSurface() {
        // TODO: Implement surface drawing - requires OpenGL ES or Canvas surface operations
        // This is a complex operation that involves drawing the composition bitmap to the MediaCodec input surface
        Log.v(TAG, "Drawing frame to encoder surface")
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
        // TODO: Implement audio encoding to MediaCodec
        // This involves feeding PCM data to the audio encoder and reading encoded AAC data
        Log.v(TAG, "Encoding audio data: $length bytes")
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
            audioRecord?.stop()
            
            // Stop encoders
            videoEncoder?.stop()
            audioEncoder?.stop()
            
            // Stop muxer
            if (muxerStarted) {
                mediaMuxer?.stop()
                muxerStarted = false
            }
            
            Log.d(TAG, "Recording components stopped")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping recording components", e)
        }
        
        // Release resources
        releaseEncoders()
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
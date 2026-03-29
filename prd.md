# UMI 海 - CAM: Dual-Camera Recording Engine

## Technical Product Requirements Document

**Version:** 1.0  
**Platform:** Android (API 21+) / iOS (13.0+)  
**Framework:** Flutter with Native MethodChannels  
**Last Updated:** March 2026

---

## 1. Introduction: Vision and Purpose

### 1.1 Engine Vision

The UMI 海 - CAM engine is a dual-camera recording system capable of simultaneously capturing video and photos from front and back cameras, composing them in real-time, and outputting a single merged media file. The engine is designed with a hardware-first approach: it detects device capabilities before attempting dual-camera operations and gracefully falls back to single-camera mode on unsupported devices.

### 1.2 Core Objectives

1. **Concurrent Capture:** Simultaneously stream from front and back cameras without frame drops
2. **Real-Time Composition:** Merge two video streams into one output file during recording (not post-processing)
3. **Hardware Abstraction:** Unified Flutter API that works across Android and iOS with platform-specific native implementations
4. **Graceful Degradation:** Detect hardware limitations and automatically switch to single-camera mode to prevent crashes
5. **Production-Ready Encoding:** Generate H.264/AAC MP4 files using native platform encoders (no external FFmpeg dependency)

### 1.3 Key Distinction: Real-Time vs. Post-Processing

This engine uses **real-time composition** during recording, not post-processing with FFmpeg:

- **Real-Time (Current Implementation):** Frames from both cameras are captured simultaneously, composed via Canvas drawing, and fed directly to the video encoder's input surface as they arrive. The final MP4 is ready immediately when recording stops.
- **Post-Processing (Not Used):** Recording each camera to separate files, then using FFmpeg to merge them afterward. This approach was rejected due to FFmpeg library dependency issues and increased processing time.

---

## 2. Architecture Stack

### 2.1 Layer Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    FLUTTER LAYER (Dart)                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │   Screens   │  │  Providers  │  │   MethodChannels    │ │
│  │  (UI Logic) │←→│  (State)    │←→│  (Service Bridge)   │ │
│  └─────────────┘  └─────────────┘  └──────────┬──────────┘ │
└────────────────────────────────────────────────┼────────────┘
                                                 │
                    ┌────────────────────────────┼────────────┐
                    │          METHOD CHANNELS     │            │
                    │  "hardware_bridge"           │            │
                    │  "camera_service"            │            │
                    │  "camera_events"             │            │
                    └────────────────────────────┼────────────┘
                                                 │
┌────────────────────────────────────────────────┼────────────┐
│                    NATIVE LAYER                 │            │
│  ┌──────────────────┐    ┌────────────────────┴──────────┐ │
│  │   ANDROID (Kotlin)│    │        iOS (Swift)            │ │
│  │  ┌──────────────┐ │    │  ┌─────────────────────────┐  │ │
│  │  │Camera2 API   │ │    │  │AVFoundation              │  │ │
│  │  │CameraManager│ │    │  │AVCaptureMultiCamSession │  │ │
│  │  │MediaCodec   │ │    │  │AVAssetWriter             │  │ │
│  │  │MediaMuxer   │ │    │  │AVAssetWriter            │  │ │
│  │  └──────────────┘ │    │  └─────────────────────────┘  │ │
│  └───────────────────┘    └──────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

### 2.2 Flutter Layer Components

#### 2.2.1 State Management (Provider Pattern)

All state management uses the **Provider pattern with ChangeNotifier**. No GetX, Riverpod, or BLoC.

```dart
// Core Provider Structure
lib/
├── providers/
│   ├── camera_capability_provider.dart    // Hardware detection state
│   └── camera_provider.dart               // Camera session state
├── services/
│   ├── hardware_bridge.dart               // MethodChannel wrapper
│   ├── native_camera_service.dart         // Camera operations
│   ├── recording_mode_service.dart        // Layout mode definitions
│   └── storage_service.dart               // File I/O
└── models/
    ├── recording_mode.dart                // Enum: pip, sideBySide, single
    └── hardware_capabilities.dart         // Data class
```

#### 2.2.2 MethodChannel Protocol

Three channels connect Flutter to native code:

| Channel Name | Purpose | Key Methods |
|-------------|---------|-------------|
| `com.example.dual_recorder/hardware_bridge` | Hardware capability queries | `isDualCameraSupported()`, `getHardwareCapabilities()` |
| `com.example.dual_recorder/camera_service` | Camera control | `initialize()`, `openCameras()`, `startRecording()`, `takePicture()` |
| `com.example.dual_recorder/camera_events` | Real-time events | Recording started, photo taken, errors |

### 2.3 Android Native Stack (Kotlin)

#### 2.3.1 Core Classes

| Class | File | Purpose |
|-------|------|---------|
| `HardwareBridge` | `HardwareBridge.kt` | Detect dual-camera hardware support |
| `DualCameraManager` | `DualCameraManager.kt` | Camera2 API wrapper, session management |
| `VideoComposer` | `VideoComposer.kt` | Frame composition and encoding |
| `MainActivity` | `MainActivity.kt` | MethodChannel registration |

#### 2.3.2 Android Dependencies

```gradle
// android/app/build.gradle key dependencies
dependencies {
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'androidx.core:core-ktx:1.12.0'
    // Camera2 API - built into Android SDK (API 21+)
    // MediaCodec/MediaMuxer - built into Android SDK
}
```

**Note:** FFmpeg was removed from the project (`ffmpeg_kit_flutter`) due to Maven repository issues. The engine uses native Canvas-based composition instead.

### 2.4 iOS Native Stack (Swift)

#### 2.4.1 Implementation Status

⚠️ **iOS is partially implemented:**

| Component | Status | Details |
|-----------|--------|---------|
| Hardware Detection | ✅ Complete | `AVCaptureMultiCamSession.isMultiCamSupported` |
| Camera Initialization | ❌ Not Implemented | No AVCaptureMultiCamSession setup |
| Frame Capture | ❌ Not Implemented | No AVCaptureVideoDataOutput |
| Video Encoding | ❌ Not Implemented | No AVAssetWriter |

Only the hardware capability check exists in `AppDelegate.swift`. The full camera pipeline requires ~2000+ lines of additional Swift code.

---

## 3. Hardware Management: The Gatekeeper Logic

### 3.1 The "Red Dot" Problem

The "Red Dot" issue refers to devices that crash or produce corrupted video when attempting concurrent camera streaming. This occurs because:

1. **ISP Bottleneck:** The Image Signal Processor (ISP) has limited bandwidth
2. **Thermal Throttling:** Dual-camera processing generates excessive heat
3. **Memory Pressure:** Two camera streams require double the buffer memory
4. **Driver Limitations:** Some devices report support but actually fail under load

When the ISP cannot handle concurrent streams, frames are dropped, resulting in:
- Gaps in the video timeline
- Audio/video desynchronization
- App crashes (ANR - Application Not Responding)
- "Red dot" indicator appearing on some devices during failed concurrent capture

### 3.2 Detection Logic: Android

#### 3.2.1 Primary Detection (API 30+)

```kotlin
// HardwareBridge.kt - Lines 24-48
fun isDualCameraSupported(): Boolean {
    return try {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            return checkDualCameraFallback()
        }
        
        // Android 11+ official API
        val concurrentCameraIds = cameraManager.concurrentCameraIds
        val isSupported = concurrentCameraIds.isNotEmpty()
        
        isSupported
    } catch (e: Exception) {
        checkDualCameraFallback()
    }
}
```

The official `CameraManager.getConcurrentCameraIds()` returns a list of camera ID sets that can run simultaneously. If the list is empty, concurrent streaming is not supported.

#### 3.2.2 Fallback Detection (API 21-29)

```kotlin
// HardwareBridge.kt - Lines 53-90
private fun checkDualCameraFallback(): Boolean {
    val cameraIdList = cameraManager.cameraIdList
    var frontCameraId: String? = null
    var backCameraId: String? = null
    
    // Enumerate cameras by lens facing
    for (cameraId in cameraIdList) {
        val characteristics = cameraManager.getCameraCharacteristics(cameraId)
        val facing = characteristics.get(CameraCharacteristics.LENS_FACING)
        
        when (facing) {
            CameraCharacteristics.LENS_FACING_FRONT -> frontCameraId = cameraId
            CameraCharacteristics.LENS_FACING_BACK -> backCameraId = cameraId
        }
    }
    
    val hasBasicDualCamera = frontCameraId != null && backCameraId != null
    
    if (hasBasicDualCamera) {
        return checkConcurrentStreamingCapability(frontCameraId!!, backCameraId!!)
    }
    
    return false
}
```

#### 3.2.3 ISP Capability Validation

```kotlin
// HardwareBridge.kt - Lines 95-121
private fun checkConcurrentStreamingCapability(frontId: String, backId: String): Boolean {
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
        
        return frontStreamConfig != null && backStreamConfig != null
    }
    
    return true  // Assume support on older devices
}
```

#### 3.2.4 Dual Camera Bypass Mode

```kotlin
// DualCameraManager.kt - Lines 163-166
// CRITICAL: Always enable dual camera if both exist
// This bypasses the official API check and tries anyway
isDualCameraSupported = frontCameraId != null && backCameraId != null
```

The engine implements a **bypass mode**: even if `getConcurrentCameraIds()` returns empty, it still attempts to open both cameras. This works on many devices that don't officially report concurrent support but can handle it in practice.

### 3.3 Detection Logic: iOS

```swift
// AppDelegate.swift - Lines 63-79
func isDualCameraSupported() -> Bool {
    if #available(iOS 13.1, *) {
        return AVCaptureMultiCamSession.isMultiCamSupported
    }
    
    // iOS 13.0 fallback: check if both cameras exist
    return hasBasicDualCameraSupport()
}
```

### 3.4 Gatekeeper Decision Tree

```
                    ┌─────────────────────┐
                    │  Check Hardware     │
                    │  Capability         │
                    └──────────┬──────────┘
                               │
              ┌────────────────┼────────────────┐
              ▼                                 ▼
    ┌─────────────────┐               ┌─────────────────┐
    │  API 30+ (R+)  │               │  API < 30       │
    │  Use official  │               │  Use fallback   │
    │  concurrentIDs │               │  detection      │
    └────────┬────────┘               └────────┬────────┘
             │                                 │
             ▼                                 ▼
    ┌─────────────────┐               ┌─────────────────┐
    │ Is list empty? │               │ Both cameras   │
    └────────┬────────┘               │ exist?         │
             │                        └────────┬────────┘
      ┌──────┴──────┐                        │
      ▼             ▼                         ▼
   ┌──────┐    ┌──────────┐            ┌──────────────┐
   │ YES  │    │   NO     │            │    YES       │
   │      │    │          │            └──────┬───────┘
   ▼      ▼    ▼          ▼                   │
┌─────┐  ┌───────┐  ┌─────────┐               ▼
│FALSE│  │ TRUE  │  │ Check  │         ┌─────────────┐
│     │  │       │  │ Stream │         │BYPASS MODE  │
└─────┘  └───────┘  │ Config │         │(Try anyway) │
                    └────────┘         └─────────────┘
```

### 3.5 User Notification

When dual-camera mode is unavailable, the engine displays a Neo-Brutalist snackbar with the limitation reason:

```kotlin
// HardwareBridge.kt - Lines 218-258
fun getDualCameraUnsupportedReason(): String? {
    return when {
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M -> 
            "Android version too old (requires API 23+)"
        cameraIdList.size < 2 -> 
            "Device has less than 2 cameras"
        !hasFront -> "No front camera found"
        !hasBack -> "No back camera found"
        concurrentSets.isEmpty() -> 
            "Hardware ISP doesn't support concurrent streaming"
        else -> null  // Dual cameras supported
    }
}
```

---

## 4. Video Pipeline: Real-Time Stream Composition

### 4.1 Pipeline Architecture

The video pipeline operates entirely in **real-time** using this flow:

```
┌──────────────┐     ┌──────────────┐
│  Front      │     │   Back       │
│  Camera     │     │   Camera     │
│  (Camera2)  │     │  (Camera2)   │
└──────┬───────┘     └──────┬───────┘
       │                    │
       ▼                    ▼
┌──────────────┐     ┌──────────────┐
│ ImageReader │     │ ImageReader  │
│  (YUV_420)  │     │  (YUV_420)   │
└──────┬───────┘     └──────┬───────┘
       │                    │
       ▼                    ▼
┌──────────────────────────────────────┐
│  YUV → ARGB Bitmap Conversion        │
│  (DualCameraManager.kt Lines 467-497)│
└──────────────────┬───────────────────┘
                   │
                   ▼
┌──────────────────────────────────────┐
│  AtomicReference<Bitmap?>           │
│  (Thread-safe frame storage)         │
│  frontFrameRef / backFrameRef        │
└──────────────────┬───────────────────┘
                   │
                   ▼
┌──────────────────────────────────────┐
│  VideoComposer Composition Loop     │
│  (33ms interval = ~30fps)            │
│  Canvas.drawBitmap() based on layout │
└──────────────────┬───────────────────┘
                   │
                   ▼
┌──────────────────────────────────────┐
│  MediaCodec Input Surface           │
│  (H.264 encoding)                   │
└──────────────────┬───────────────────┘
                   │
        ┌──────────┴──────────┐
        ▼                     ▼
┌───────────────┐    ┌────────────────┐
│  AudioRecord  │    │   MediaMuxer   │
│  (AAC encode) │    │  (MP4 output)  │
└───────────────┘    └────────────────┘
```

### 4.2 Camera Session Setup

#### 4.2.1 Texture Registry

Flutter preview requires texture IDs from native code:

```kotlin
// DualCameraManager.kt - Lines 240-248
fun initialize(callback: (Boolean, String?) -> Unit) {
    // Create texture entries for Flutter preview
    frontTextureEntry = textureRegistry.createSurfaceTexture()
    backTextureEntry = textureRegistry.createSurfaceTexture()
    
    frontSurfaceTexture = frontTextureEntry?.surfaceTexture()
    backSurfaceTexture = backTextureEntry?.surfaceTexture()
    
    // Set preview buffer size
    frontSurfaceTexture?.setDefaultBufferSize(1280, 720)
    backSurfaceTexture?.setDefaultBufferSize(1280, 720)
}
```

#### 4.2.2 Capture Session Configuration

```kotlin
// DualCameraManager.kt - Lines 350-423
private fun createPreviewSession(...) {
    // Preview surface for Flutter display
    val previewSurface = Surface(frontSurfaceTexture)
    
    // Frame capture surface for composition
    frontImageReader = ImageReader.newInstance(
        640, 480,  // Capture resolution (optimized for performance)
        ImageFormat.YUV_420_888,
        2  // Max images in buffer
    )
    
    // Photo capture surface
    frontPhotoReader = ImageReader.newInstance(
        1920, 1080,
        ImageFormat.JPEG,
        2
    )
}
```

### 4.3 Frame Capture Pipeline

#### 4.3.1 ImageReader Callbacks

```kotlin
// DualCameraManager.kt - Lines 367-374
frontImageReader.setOnImageAvailableListener({ reader ->
    val image = reader.acquireLatestImage()
    image?.use {
        // Convert YUV to ARGB Bitmap
        val bitmap = yuvToBitmap(it)
        
        // Send to VideoComposer for encoding
        videoComposer?.updateFrontFrameBitmap(bitmap)
    }
}, backgroundHandler)
```

#### 4.3.2 YUV to ARGB Conversion

```kotlin
// DualCameraManager.kt - Lines 467-497
private fun yuvToBitmap(image: Image): Bitmap {
    val yBuffer = image.planes[0].buffer
    val uBuffer = image.planes[1].buffer
    val vBuffer = image.planes[2].buffer
    
    val ySize = yBuffer.remaining()
    val uSize = uBuffer.remaining()
    
    val nv21 = ByteArray(ySize + uSize)
    yBuffer.get(nv21, 0, ySize)
    vBuffer.get(nv21, ySize, vBuffer.remaining())
    
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
        100,
        out
    )
    
    return BitmapFactory.decodeByteArray(
        out.toByteArray(),
        0,
        out.size()
    )
}
```

#### 4.3.3 Frame Rate Limiting

```kotlin
// DualCameraManager.kt - Lines 126-129
private val frameIntervalMs = 33L  // ~30fps limit

// In frame callback - throttle to prevent overload
if (currentTime - lastFrontFrameTime < frameIntervalMs) {
    return  // Skip frame
}
lastFrontFrameTime = currentTime
```

### 4.4 Double-Buffered Frame Storage

The engine uses `AtomicReference<Bitmap?>` for thread-safe frame updates:

```kotlin
// VideoComposer.kt - Lines 56-58
private val frontFrameRef = AtomicReference<Bitmap?>(null)
private val backFrameRef = AtomicReference<Bitmap?>(null)

// Update method - thread safe
fun updateFrontFrameBitmap(bitmap: Bitmap) {
    if (!isRecording.get()) return
    
    val copy = bitmap.copy(Bitmap.Config.ARGB_8888, false)
    val old = frontFrameRef.getAndSet(copy)
    
    // Recycle old bitmap on background thread
    old?.let { 
        compositionHandler?.post { 
            if (!it.isRecycled) it.recycle() 
        }
    }
}
```

### 4.5 Real-Time Composition

#### 4.5.1 Composition Loop

```kotlin
// VideoComposer.kt - Lines 226-237
private fun startCompositionLoop() {
    val frameIntervalMs = 1000L / frameRate  // 33ms for 30fps
    
    compositionHandler?.post(object : Runnable {
        override fun run() {
            if (isRecording.get() && !isStopping.get()) {
                composeAndSubmitFrame()
                compositionHandler?.postDelayed(this, frameIntervalMs)
            }
        }
    })
}
```

#### 4.5.2 Canvas Drawing

```kotlin
// VideoComposer.kt - Lines 394-420
private fun composeAndSubmitFrame() {
    val surface = inputSurface ?: return
    
    val canvas = surface.lockCanvas(null)
    canvas.drawColor(Color.BLACK)  // Clear
    
    // Get current frames (atomic read, don't modify reference)
    val frontBitmap = frontFrameRef.get()
    val backBitmap = backFrameRef.get()
    
    // Compose based on layout
    composeFrames(canvas, frontBitmap, backBitmap)
    
    surface.unlockCanvasAndPost(canvas)
}
```

#### 4.5.3 Layout Implementations

**Side-by-Side Horizontal (50/50 split):**

```kotlin
// VideoComposer.kt - Lines 463-482
private fun composeSideBySideHorizontal(canvas: Canvas, back: Bitmap?, front: Bitmap?) {
    val halfWidth = outputWidth / 2
    
    // Front on left half
    canvas.drawBitmap(front, 
        Rect(0, 0, front.width, front.height),
        Rect(0, 0, halfWidth, outputHeight),
        paint
    )
    
    // Back on right half
    canvas.drawBitmap(back,
        Rect(0, 0, back.width, back.height),
        Rect(halfWidth, 0, outputWidth, outputHeight),
        paint
    )
    
    // Black divider line
    canvas.drawRect(
        halfWidth - 2, 0f, halfWidth + 2, outputHeight.toFloat(),
        borderPaint
    )
}
```

**Picture-in-Picture (PiP):**

```kotlin
// VideoComposer.kt - Lines 505-544
private fun composePiP(canvas: Canvas, main: Bitmap?, pip: Bitmap?, gravity: PipGravity) {
    // Main camera fullscreen
    canvas.drawBitmap(main,
        Rect(0, 0, main.width, main.height),
        Rect(0, 0, outputWidth, outputHeight),
        paint
    )
    
    // PiP overlay (1/4 size with margin)
    val pipWidth = outputWidth / 4
    val pipHeight = outputHeight / 4
    val margin = 32
    
    val left = when (gravity) {
        PipGravity.TOP_LEFT, PipGravity.BOTTOM_LEFT -> margin
        PipGravity.TOP_RIGHT, PipGravity.BOTTOM_RIGHT -> outputWidth - pipWidth - margin
    }
    
    val top = when (gravity) {
        PipGravity.TOP_LEFT, PipGravity.TOP_RIGHT -> margin
        PipGravity.BOTTOM_LEFT, PipGravity.BOTTOM_RIGHT -> outputHeight - pipHeight - margin
    }
    
    // White border around PiP
    canvas.drawRect(
        (left - 4).toFloat(), (top - 4).toFloat(),
        (left + pipWidth + 4).toFloat(), (top + pipHeight + 4).toFloat(),
        whiteBorderPaint
    )
    
    // PiP content
    canvas.drawBitmap(pip,
        Rect(0, 0, pip.width, pip.height),
        Rect(left, top, left + pipWidth, top + pipHeight),
        paint
    )
}
```

### 4.6 Video Encoding

#### 4.6.1 MediaCodec Configuration

```kotlin
// VideoComposer.kt - Lines 126-141
private fun setupVideoEncoder() {
    val format = MediaFormat.createVideoFormat(
        MediaFormat.MIMETYPE_VIDEO_AVC,  // H.264
        outputWidth,
        outputHeight
    ).apply {
        setInteger(MediaFormat.KEY_COLOR_FORMAT, 
            MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
        setInteger(MediaFormat.KEY_BIT_RATE, bitRate)
        setInteger(MediaFormat.KEY_FRAME_RATE, frameRate)
        setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)  // I-frame every second
    }
    
    videoEncoder = MediaCodec.createEncoderByType(VIDEO_MIME_TYPE).apply {
        configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        inputSurface = createInputSurface()  // Canvas surface for composition
        start()
    }
}
```

#### 4.6.2 Quality Presets

```kotlin
// DualCameraManager.kt - Lines 46-51
enum class VideoQuality(
    val width: Int, 
    val height: Int, 
    val bitRate: Int, 
    val frameRate: Int
) {
    LOW(640, 480, 2_000_000, 24),       // 2 Mbps @ 24fps
    MEDIUM(1280, 720, 5_000_000, 30),  // 5 Mbps @ 30fps (DEFAULT)
    HIGH(1920, 1080, 10_000_000, 30),   // 10 Mbps @ 30fps
    ULTRA(1920, 1080, 15_000_000, 60)   // 15 Mbps @ 60fps
}
```

### 4.7 Audio Encoding

#### 4.7.1 AudioRecord Setup

```kotlin
// VideoComposer.kt - Lines 143-192
private fun setupAudioEncoder(): Boolean {
    val minBufferSize = AudioRecord.getMinBufferSize(
        44100,  // Sample rate
        AudioFormat.CHANNEL_IN_MONO,
        AudioFormat.ENCODING_PCM_16BIT
    )
    
    audioRecord = AudioRecord(
        MediaRecorder.AudioSource.MIC,
        44100,
        AudioFormat.CHANNEL_IN_MONO,
        AudioFormat.ENCODING_PCM_16BIT,
        minBufferSize * 4
    )
    
    // AAC encoder configuration
    val audioFormat = MediaFormat.createAudioFormat(
        MediaFormat.MIMETYPE_AUDIO_AAC,
        44100,
        1  // Mono
    ).apply {
        setInteger(MediaFormat.KEY_BIT_RATE, 128000)  // 128 kbps
        setInteger(MediaFormat.KEY_AAC_PROFILE,
            MediaCodecInfo.CodecProfileLevel.AACObjectLC)
    }
    
    audioEncoder = MediaCodec.createEncoderByType(AUDIO_MIME_TYPE).apply {
        configure(audioFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        start()
    }
    
    return true
}
```

### 4.8 Synchronization Strategy

#### 4.8.1 Timestamp Generation

```kotlin
// VideoComposer.kt - Lines 114, 247, 605
var startTimeNs = 0L

// On recording start
startTimeNs = System.nanoTime()

// Audio timestamp
val audioStartTime = System.nanoTime()
val presentationTimeUs = (System.nanoTime() - audioStartTime) / 1000

// Video timestamp
bufferInfo.presentationTimeUs = (System.nanoTime() - startTimeNs) / 1000
```

#### 4.8.2 Audio-Video Sync Logic

1. Both video and audio use `System.nanoTime()` as the time base
2. Audio recording starts first to establish the baseline
3. Video frames use the same time base offset by `startTimeNs`
4. Presentation timestamps in the MP4 container align frames with audio samples

### 4.9 Muxing

```kotlin
// VideoComposer.kt - Lines 194-199, 632-644
private fun setupMuxer() {
    muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
}

private fun checkStartMuxer() {
    synchronized(muxerLock) {
        if (!muxerStarted && tracksAdded >= expectedTracks) {
            muxer?.start()
            muxerStarted = true
        }
    }
}

// Track addition - video
videoTrackIndex = muxer?.addTrack(encoder.outputFormat)
tracksAdded++

// Track addition - audio  
audioTrackIndex = muxer?.addTrack(encoder.outputFormat)
tracksAdded++

// Writing samples
muxer?.writeSampleData(videoTrackIndex, outputBuffer, bufferInfo)
muxer?.writeSampleData(audioTrackIndex, outputBuffer, bufferInfo)
```

---

## 5. Image Pipeline: Dual-Photo Capture

### 5.1 Simultaneous Capture Logic

The dual-photo feature captures frames from both cameras at the exact same millisecond:

```kotlin
// DualCameraManager.kt - Lines 668-690
fun takePicture(callback: (Map<String, String?>?) -> Unit) {
    photoCaptureCallback = callback
    pendingPhotoBitmaps.clear()
    
    val hasBack = backCamera != null && backCaptureSession != null
    val hasFront = frontCamera != null && frontCaptureSession != null && isDualCameraSupported
    
    photosExpected = (if (hasBack) 1 else 0) + (if (hasFront) 1 else 0)
    
    // Shared timestamp for synchronization
    val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
    
    // Capture both cameras simultaneously
    if (hasBack) {
        capturePhoto(backCamera!!, backCaptureSession!!, backPhotoReader!!, true, timestamp)
    }
    if (hasFront) {
        capturePhoto(frontCamera!!, frontCaptureSession!!, frontPhotoReader!!, false, timestamp)
    }
}
```

### 5.2 Photo Capture Request

```kotlin
// DualCameraManager.kt - Lines 692-720
private fun capturePhoto(
    camera: CameraDevice,
    session: CameraCaptureSession,
    imageReader: ImageReader,
    isBack: Boolean,
    timestamp: String
) {
    val captureBuilder = camera.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE)
    captureBuilder.addTarget(imageReader.surface)
    captureBuilder.set(CaptureRequest.CONTROL_AF_MODE, 
        CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
    captureBuilder.set(CaptureRequest.JPEG_ORIENTATION, 
        if (isBack) 90 else 270)  // Front needs 270° rotation
    
    imageReader.setOnImageAvailableListener({ reader ->
        val image = reader.acquireLatestImage()
        image?.use {
            processPhotoBitmap(it, isBack, timestamp)
        }
    }, backgroundHandler)
    
    session.capture(captureBuilder.build(), captureCallback, backgroundHandler)
}
```

### 5.3 Wait for Both Frames

```kotlin
// DualCameraManager.kt - Lines 736-743
private fun onPhotoCaptured(key: String, bitmap: Bitmap?, timestamp: String) {
    pendingPhotoBitmaps[key] = bitmap
    
    // Wait until ALL cameras have captured
    if (pendingPhotoBitmaps.size >= photosExpected) {
        composeAndSavePhoto(timestamp)
    }
}
```

### 5.4 Bitmap Stitching

```kotlin
// DualCameraManager.kt - Lines 792-880
private fun composePhotoBitmaps(backBitmap: Bitmap, frontBitmap: Bitmap): Bitmap {
    // Determine output size based on layout
    val outputWidth: Int
    val outputHeight: Int
    
    when (currentLayout) {
        PreviewLayout.SIDE_BY_SIDE_HORIZONTAL -> {
            outputWidth = 1920
            outputHeight = 1080
        }
        PreviewLayout.SIDE_BY_SIDE_VERTICAL -> {
            outputWidth = 1080
            outputHeight = 1920
        }
        else -> {  // PiP and single layouts
            outputWidth = 1080
            outputHeight = 1920
        }
    }
    
    val composedBitmap = Bitmap.createBitmap(
        outputWidth, outputHeight, Bitmap.Config.ARGB_8888
    )
    val canvas = Canvas(composedBitmap)
    val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    
    // Apply same composition logic as video
    when (currentLayout) {
        PreviewLayout.SIDE_BY_SIDE_HORIZONTAL -> {
            val halfWidth = outputWidth / 2
            // Front on left
            canvas.drawBitmap(frontBitmap,
                Rect(0, 0, frontBitmap.width, frontBitmap.height),
                Rect(0, 0, halfWidth, outputHeight),
                paint
            )
            // Back on right
            canvas.drawBitmap(backBitmap,
                Rect(0, 0, backBitmap.width, backBitmap.height),
                Rect(halfWidth, 0, outputWidth, outputHeight),
                paint
            )
        }
        // ... other layouts follow same pattern
        else -> { /* PiP or single */ }
    }
    
    return composedBitmap
}
```

### 5.5 JPEG Output

```kotlin
// DualCameraManager.kt - Lines 882-950
private fun saveComposedPhoto(bitmap: Bitmap, timestamp: String): String? {
    val filename = "IMG_${timestamp}_dual.jpg"
    
    // JPEG compression at 95% quality
    val success = bitmap.compress(
        Bitmap.CompressFormat.JPEG,
        95,  // Quality: 0-100
        outputStream
    )
    
    // Save to MediaStore (Android Q+) or file system
}
```

---

## 6. Feature Logic: Smart Selfie Crop

### 6.1 Concept

The Smart Selfie feature converts a 4:3 (1.333 aspect ratio) front camera feed into a 16:9 (1.778 aspect ratio) "landscape" crop for selfie videos. This is achieved through:

1. **Aspect Ratio Tween:** Smoothly animating from 4:3 to 16:9
2. **Scale Animation:** Slightly zooming in (1.0 → 1.2) to simulate a wider field of view
3. **Center Crop:** Keeping the crop centered on the subject

### 6.2 Aspect Ratio Mathematics

```
Source (4:3):  ████████████████
               ████████████████
               ████████████████
               ████████████████
                    ↓ Crop
Target (16:9): ████████████████
               ████████████████
               
Ratio: 4:3 = 1.333...
       16:9 = 1.778...

Scale Factor: 1.778 / 1.333 = 1.333 (or ~1.2 used in implementation)
```

### 6.3 Flutter Implementation

```dart
// smart_horizontal_selfie.dart - Lines 32-61
class _SmartHorizontalSelfieState extends State<SmartHorizontalSelfie> 
    with SingleTickerProviderStateMixin {
  
  // Aspect ratios
  static const double portraitAspectRatio = 4.0 / 3.0;   // 1.333
  static const double landscapeAspectRatio = 16.0 / 9.0;  // 1.778
  
  late AnimationController _animationController;
  late Animation<double> _aspectRatioAnimation;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    _animationController = AnimationController(
      duration: Duration(milliseconds: 600),  // 600ms transition
      vsync: this,
    );
    
    // Tween from 4:3 to 16:9
    _aspectRatioAnimation = Tween<double>(
      begin: portraitAspectRatio,   // 1.333
      end: landscapeAspectRatio,    // 1.778
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,  // Smooth curve
    ));
    
    // Scale from 1.0 to 1.2 for zoom effect
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutBack,  // Slight overshoot for polish
    ));
  }
}
```

### 6.4 Widget Composition

```dart
// smart_horizontal_selfie.dart - Lines 88-133
@override
Widget build(BuildContext context) {
  return AnimatedBuilder(
    animation: _animationController,
    builder: (context, child) {
      return Stack(
        children: [
          // Camera with animated crop
          ClipRect(
            child: OverflowBox(
              alignment: Alignment.center,
              child: Transform.scale(
                scale: _scaleAnimation.value,  // 1.0 → 1.2
                child: AspectRatio(
                  aspectRatio: _aspectRatioAnimation.value,  // 4:3 → 16:9
                  child: widget.child,
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
```

### 6.5 Crop Calculation Utility

```dart
// smart_horizontal_selfie.dart - Lines 228-243
class SmartHorizontalUtils {
  /// Calculate crop dimensions for 16:9 from 4:3 source
  static Size calculateCropSize(Size sourceSize) {
    const sourceAspectRatio = 4.0 / 3.0;      // 1.333
    const targetAspectRatio = 16.0 / 9.0;     // 1.778
    
    if (sourceSize.width / sourceSize.height > targetAspectRatio) {
      // Width is limiting factor
      final newHeight = sourceSize.width / targetAspectRatio;
      return Size(sourceSize.width, newHeight);
    } else {
      // Height is limiting factor  
      final newWidth = sourceSize.height * targetAspectRatio;
      return Size(newWidth, sourceSize.height);
    }
  }
}
```

### 6.6 Animation Curves

| Parameter | From | To | Curve | Duration |
|-----------|------|-----|-------|----------|
| Aspect Ratio | 1.333 (4:3) | 1.778 (16:9) | easeInOutCubic | 600ms |
| Scale | 1.0 | 1.2 | easeInOutBack | 600ms |

The `easeInOutBack` curve provides a subtle "overshoot" effect that makes the transition feel more polished and responsive.

---

## 7. Performance & Memory Management

### 7.1 Frame Rate Limiter

```kotlin
// DualCameraManager.kt - Line 129
private val frameIntervalMs = 33L  // ~30fps maximum

// In frame callback
if (currentTime - lastFrontFrameTime < frameIntervalMs) {
    return  // Skip - prevent ISP overload
}
lastFrontFrameTime = currentTime
```

**Rationale:** Hard-limiting to 30fps prevents ISP bottleneck on weaker devices while still providing smooth video.

### 7.2 Threading Model

```
┌──────────────────────────────────────────────────────────────┐
│                       MAIN THREAD                             │
│  Flutter UI, State Management, MethodChannel callbacks       │
└──────────────────────────┬───────────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        ▼                  ▼                  ▼
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│   Camera      │  │  Composition  │  │    Audio      │
│   Handler     │  │    Thread     │  │    Thread     │
│  (HandlerThread)│  │ (HandlerThread)│  │   (Thread)   │
└───────────────┘  └───────────────┘  └───────────────┘
        │                  │                  │
        └──────────────────┴──────────────────┘
                           │
                           ▼
                    ┌───────────────┐
                    │  MediaCodec   │
                    │  Encoder       │
                    └───────────────┘
                           │
                           ▼
                    ┌───────────────┐
                    │   MediaMuxer   │
                    │   (MP4 writer) │
                    └───────────────┘
```

```kotlin
// VideoComposer.kt - Lines 201-224
private fun startThreads() {
    // Video encoder thread
    videoEncoderThread = HandlerThread("VideoEncoderThread").apply { start() }
    videoEncoderHandler = Handler(videoEncoderThread!!.looper)
    
    // Composition thread
    compositionThread = HandlerThread("CompositionThread").apply { start() }
    compositionHandler = Handler(compositionThread!!.looper)
    
    // Audio recording thread
    if (audioEnabled) {
        startAudioRecording()
    }
}
```

### 7.3 Bitmap Recycling

```kotlin
// VideoComposer.kt - Lines 355-392
fun updateFrontFrameBitmap(bitmap: Bitmap) {
    // Create copy for thread safety
    val copy = bitmap.copy(Bitmap.Config.ARGB_8888, false)
    
    // Atomically swap old frame
    val old = frontFrameRef.getAndSet(copy)
    
    // Recycle old bitmap on background thread
    old?.let { 
        compositionHandler?.post { 
            if (!it.isRecycled) it.recycle() 
        }
    }
}
```

### 7.4 Memory Budget

| Component | Resolution | Color Format | Memory per Frame |
|----------|------------|--------------|------------------|
| Front Preview | 1280×720 | YUV_420 | ~1.4 MB |
| Back Preview | 1280×720 | YUV_420 | ~1.4 MB |
| Frame Capture | 640×480 | YUV_420 | ~460 KB |
| ARGB Bitmap | 640×480 | ARGB_8888 | ~1.2 MB |
| Encoder Surface | 1920×1080 | Native | ~8 MB |

**Total Peak Memory:** ~15-20 MB for dual-camera capture and encoding.

### 7.5 Temporary File Cleanup

```kotlin
// VideoComposer.kt - Lines 96, 697-704
fun start(): Boolean {
    // Ensure output directory exists
    File(outputPath).parentFile?.mkdirs()
}

fun stop(): String? {
    // Validate output before returning
    val file = File(outputPath)
    return if (file.exists() && file.length() > 0) {
        outputPath
    } else {
        null  // Don't return invalid files
    }
}
```

### 7.6 MediaCodec Surface Input

Instead of using texture surfaces (which require OpenGL), the engine uses MediaCodec's native input surface:

```kotlin
// VideoComposer.kt - Lines 126-141
val format = MediaFormat.createVideoFormat(VIDEO_MIME_TYPE, width, height).apply {
    setInteger(MediaFormat.KEY_COLOR_FORMAT, 
        MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
}

videoEncoder = MediaCodec.createEncoderByType(VIDEO_MIME_TYPE).apply {
    configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
    inputSurface = createInputSurface()  // Native surface for Canvas
    start()
}

// Composition directly to encoder surface
val canvas = inputSurface.lockCanvas(null)
canvas.drawColor(Color.BLACK)
composeFrames(canvas, frontBitmap, backBitmap)
inputSurface.unlockCanvasAndPost(canvas)
```

**Benefits:**
- No OpenGL dependency
- Direct Canvas-to-encoder pipeline
- Lower memory overhead
- Works on all Android devices (API 21+)

### 7.7 Error Handling

```kotlin
// VideoComposer.kt - Lines 88-123
fun start(): Boolean {
    if (isRecording.get()) {
        Log.w(TAG, "Already recording")
        return false
    }
    
    return try {
        setupVideoEncoder()
        setupMuxer()
        audioEnabled = setupAudioEncoder()
        
        startThreads()
        
        isRecording.set(true)
        startTimeNs = System.nanoTime()
        
        true
    } catch (e: Exception) {
        Log.e(TAG, "Failed to start VideoComposer", e)
        releaseEncoders()
        false
    }
}
```

---

## Appendix A: File Structure Reference

### Android Native (Kotlin)

```
android/app/src/main/kotlin/com/example/dual_recorder/
├── MainActivity.kt           # MethodChannel registration, state management
├── HardwareBridge.kt         # Hardware capability detection
├── DualCameraManager.kt      # Camera2 API, sessions, photo capture
└── VideoComposer.kt          # Composition, encoding, muxing
```

### iOS Native (Swift)

```
ios/Runner/
└── AppDelegate.swift         # MethodChannel registration, hardware detection only
```

### Flutter (Dart)

```
lib/
├── main.dart
├── models/
│   ├── recording_mode.dart
│   └── hardware_capabilities.dart
├── providers/
│   ├── camera_capability_provider.dart
│   └── camera_provider.dart
├── services/
│   ├── hardware_bridge.dart
│   ├── native_camera_service.dart
│   ├── recording_mode_service.dart
│   └── storage_service.dart
├── widgets/
│   ├── smart_horizontal_selfie.dart
│   ├── recording_mode_widget.dart
│   └── ocean_background_painter.dart
└── theme/
    ├── ocean_colors.dart
    └── ocean_theme.dart
```

---

## Appendix B: MethodChannel Protocol Reference

### Channel: `com.example.dual_recorder/hardware_bridge`

| Method | Parameters | Returns | Description |
|--------|-----------|---------|-------------|
| `isDualCameraSupported` | none | `bool` | Check concurrent camera support |
| `getHardwareCapabilities` | none | `Map<String, Object>` | Detailed device info |
| `canUseCamerasConcurrently` | `List<String> cameraIds` | `bool` | Check specific cameras |
| `getDualCameraUnsupportedReason` | none | `String?` | Human-readable limitation |

### Channel: `com.example.dual_recorder/camera_service`

| Method | Parameters | Returns | Description |
|--------|-----------|---------|-------------|
| `initialize` | none | `bool` | Setup texture registry |
| `openCameras` | none | `Map<String, int>` | Open front/back cameras |
| `closeCameras` | none | `bool` | Release camera resources |
| `startRecording` | `Map<String, dynamic>` | `bool` | Start video capture |
| `stopRecording` | none | `String?` | Stop and return file path |
| `takePicture` | none | `Map<String, String?>` | Capture dual-photo |
| `setLayout` | `String layoutName` | `bool` | Change composition layout |
| `setQuality` | `String qualityName` | `bool` | Change quality preset |
| `swapCameras` | none | `bool` | Swap front/back positions |

---

## Appendix C: Known Limitations

| Limitation | Severity | Workaround |
|------------|----------|------------|
| iOS: No camera pipeline | 🔴 Critical | Requires implementation |
| Frame rate capped at 30fps | ⚠️ Medium | Hardware limitation |
| No pause/resume recording | ⚠️ Medium | Requires implementation |
| Audio from single source | ⚠️ Medium | Only primary mic used |

---

**Document End**

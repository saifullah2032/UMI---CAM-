import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../providers/camera_provider.dart' show CameraLayout;
import '../providers/settings_provider.dart';

/**
 * Camera initialization result data
 */
class CameraInitResult {
  final int frontTextureId;
  final int backTextureId;
  final int previewWidth;
  final int previewHeight;
  
  const CameraInitResult({
    required this.frontTextureId,
    required this.backTextureId, 
    required this.previewWidth,
    required this.previewHeight,
  });
  
  factory CameraInitResult.fromMap(Map<dynamic, dynamic> map) {
    final previewSize = map['previewSize'] as Map<dynamic, dynamic>?;
    
    return CameraInitResult(
      frontTextureId: map['frontTextureId'] as int,
      backTextureId: map['backTextureId'] as int,
      previewWidth: previewSize?['width'] as int? ?? 1280,
      previewHeight: previewSize?['height'] as int? ?? 720,
    );
  }
  
  @override
  String toString() => 'CameraInitResult(frontTexture: $frontTextureId, backTexture: $backTextureId, size: ${previewWidth}x$previewHeight)';
}

/**
 * Camera status information
 */
class CameraStatus {
  final bool isInitialized;
  final bool isCamerasOpen;
  final bool frontCameraConnected;
  final bool backCameraConnected;
  final int frontTextureId;
  final int backTextureId;
  final Map<String, dynamic> additionalInfo;
  
  const CameraStatus({
    required this.isInitialized,
    required this.isCamerasOpen,
    required this.frontCameraConnected,
    required this.backCameraConnected,
    required this.frontTextureId,
    required this.backTextureId,
    this.additionalInfo = const {},
  });
  
  factory CameraStatus.fromMap(Map<dynamic, dynamic> map) {
    return CameraStatus(
      isInitialized: map['isInitialized'] as bool? ?? false,
      isCamerasOpen: map['isCamerasOpen'] as bool? ?? false,
      frontCameraConnected: map['frontCameraConnected'] as bool? ?? false,
      backCameraConnected: map['backCameraConnected'] as bool? ?? false,
      frontTextureId: map['frontTextureId'] as int? ?? -1,
      backTextureId: map['backTextureId'] as int? ?? -1,
      additionalInfo: Map<String, dynamic>.from(map),
    );
  }
  
  @override
  String toString() => 'CameraStatus(init: $isInitialized, open: $isCamerasOpen, front: $frontCameraConnected, back: $backCameraConnected)';
}

/**
 * Recording result data
 */
class RecordingResult {
  final bool success;
  final String? filePath;
  final String? error;
  
  const RecordingResult({
    required this.success,
    this.filePath,
    this.error,
  });
  
  factory RecordingResult.fromMap(Map<dynamic, dynamic> map) {
    return RecordingResult(
      success: map['success'] as bool? ?? false,
      filePath: map['filePath'] as String?,
      error: map['error'] as String?,
    );
  }
  
  @override
  String toString() => 'RecordingResult(success: $success, filePath: $filePath, error: $error)';
}

/**
 * Recording status information
 */
class RecordingStatus {
  final bool isRecording;
  final String layout;
  final String outputFile;
  final double duration;
  final Map<String, dynamic> additionalInfo;
  
  const RecordingStatus({
    required this.isRecording,
    required this.layout,
    required this.outputFile,
    required this.duration,
    this.additionalInfo = const {},
  });
  
  factory RecordingStatus.fromMap(Map<dynamic, dynamic> map) {
    return RecordingStatus(
      isRecording: map['isRecording'] as bool? ?? false,
      layout: map['layout'] as String? ?? 'pip',
      outputFile: map['outputFile'] as String? ?? '',
      duration: (map['duration'] as num?)?.toDouble() ?? 0.0,
      additionalInfo: Map<String, dynamic>.from(map),
    );
  }
  
  @override
  String toString() => 'RecordingStatus(recording: $isRecording, layout: $layout, duration: ${duration}s)';
}
class CameraException implements Exception {
  final String message;
  final String? code;
  final String? details;
  
  const CameraException(this.message, {this.code, this.details});
  
  @override
  String toString() {
    if (code != null) {
      return 'CameraException($code): $message';
    }
    return 'CameraException: $message';
  }
}

/**
 * NativeCameraService - Flutter MethodChannel wrapper for dual-camera operations
 * 
 * Provides a clean Dart API for:
 * - Camera initialization with texture IDs
 * - Opening/closing camera sessions
 * - Status monitoring and error handling
 */
class NativeCameraService {
  static const String _channelName = 'com.example.dual_recorder/hardware_bridge';
  static const MethodChannel _channel = MethodChannel(_channelName);
  
  static const String _tag = 'NativeCameraService';
  
  /**
   * Initialize the dual camera system
   * Returns texture IDs for Flutter preview widgets
   */
  static Future<CameraInitResult> initializeCameras() async {
    try {
      debugPrint('$_tag: Initializing dual camera system...');
      
      final result = await _channel.invokeMethod<Map<Object?, Object?>>('initializeCameras');
      
      if (result == null) {
        throw Exception('Native camera initialization returned null');
      }
      
      final initResult = CameraInitResult.fromMap(result);
      
      debugPrint('$_tag: Camera initialization successful - $initResult');
      return initResult;
      
    } on PlatformException catch (e) {
      debugPrint('$_tag: Platform exception during initialization: ${e.code} - ${e.message}');
      throw CameraException('Initialization failed: ${e.message}', code: e.code);
    } catch (e) {
      debugPrint('$_tag: Unexpected error during initialization: $e');
      throw CameraException('Initialization failed: $e');
    }
  }
  
  /**
   * Open both cameras and start streaming
   * 
   * @param bypassMode - Attempt dual camera even if not officially supported
   */
  static Future<void> openCameras({bool bypassMode = false}) async {
    try {
      debugPrint('$_tag: Opening cameras (bypassMode: $bypassMode)...');
      
      final result = await _channel.invokeMethod<bool>('openCameras', {
        'bypassMode': bypassMode,
      });
      
      if (result == true) {
        debugPrint('$_tag: Cameras opened successfully');
      } else {
        throw Exception('Camera opening returned false');
      }
      
    } on PlatformException catch (e) {
      debugPrint('$_tag: Platform exception during camera opening: ${e.code} - ${e.message}');
      throw CameraException('Failed to open cameras: ${e.message}', code: e.code);
    } catch (e) {
      debugPrint('$_tag: Unexpected error during camera opening: $e');
      throw CameraException('Failed to open cameras: $e');
    }
  }
  
  /**
   * Close cameras and clean up resources
   */
  static Future<void> closeCameras() async {
    try {
      debugPrint('$_tag: Closing cameras...');
      
      final result = await _channel.invokeMethod<bool>('closeCameras');
      
      if (result == true) {
        debugPrint('$_tag: Cameras closed successfully');
      } else {
        throw Exception('Camera closing returned false');
      }
      
    } on PlatformException catch (e) {
      debugPrint('$_tag: Platform exception during camera closing: ${e.code} - ${e.message}');
      throw CameraException('Failed to close cameras: ${e.message}', code: e.code);
    } catch (e) {
      debugPrint('$_tag: Unexpected error during camera closing: $e');
      throw CameraException('Failed to close cameras: $e');
    }
  }
  
  /**
   * Get current camera status for monitoring and debugging
   */
  static Future<CameraStatus> getCameraStatus() async {
    try {
      debugPrint('$_tag: Getting camera status...');
      
      final result = await _channel.invokeMethod<Map<Object?, Object?>>('getCameraStatus');
      
      if (result == null) {
        throw Exception('Camera status returned null');
      }
      
      final status = CameraStatus.fromMap(result);
      
      debugPrint('$_tag: Camera status retrieved - $status');
      return status;
      
    } on PlatformException catch (e) {
      debugPrint('$_tag: Platform exception getting camera status: ${e.code} - ${e.message}');
      // Return error status instead of throwing
      return CameraStatus(
        isInitialized: false,
        isCamerasOpen: false,
        frontCameraConnected: false,
        backCameraConnected: false,
        frontTextureId: -1,
        backTextureId: -1,
        additionalInfo: {'error': e.message, 'errorCode': e.code},
      );
    } catch (e) {
      debugPrint('$_tag: Unexpected error getting camera status: $e');
      return CameraStatus(
        isInitialized: false,
        isCamerasOpen: false,
        frontCameraConnected: false,
        backCameraConnected: false,
        frontTextureId: -1,
        backTextureId: -1,
        additionalInfo: {'error': e.toString()},
      );
    }
  }
  
  /**
   * Check if current platform supports dual camera operations
   */
  static bool get isSupported {
    return Platform.isAndroid || Platform.isIOS;
  }
  
  /**
   * Get platform-specific information for debugging
   */
  static String get platformInfo {
    if (Platform.isAndroid) {
      return 'Android - Camera2 API with DualCameraManager';
    } else if (Platform.isIOS) {
      return 'iOS - AVCaptureMultiCamSession';
    } else {
      return 'Unsupported platform: ${Platform.operatingSystem}';
    }
  }
  
  // ============================================================
  // RECORDING OPERATIONS
  // ============================================================
  
  /**
   * Initialize the recording system
   */
  static Future<void> initializeRecording() async {
    try {
      debugPrint('$_tag: Initializing recording system...');
      
      final result = await _channel.invokeMethod<bool>('initializeRecording');
      
      if (result == true) {
        debugPrint('$_tag: Recording system initialized successfully');
      } else {
        throw Exception('Recording initialization returned false');
      }
      
    } on PlatformException catch (e) {
      debugPrint('$_tag: Platform exception during recording initialization: ${e.code} - ${e.message}');
      throw CameraException('Failed to initialize recording: ${e.message}', code: e.code);
    } catch (e) {
      debugPrint('$_tag: Unexpected error during recording initialization: $e');
      throw CameraException('Failed to initialize recording: $e');
    }
  }
  
  /**
   * Start recording with specified layout and video quality
   */
  static Future<RecordingResult> startRecording(CameraLayout layout, {VideoQuality quality = VideoQuality.medium}) async {
    try {
      debugPrint('$_tag: Starting recording with layout: $layout, quality: $quality...');
      
      final layoutName = _layoutToString(layout);
      
      final result = await _channel.invokeMethod<Map<Object?, Object?>>('startRecording', {
        'layout': layoutName,
        'quality': quality.stringValue,
        'width': quality.width,
        'height': quality.height,
        'bitrate': quality.bitrate,
      });
      
      if (result == null) {
        throw Exception('Start recording returned null');
      }
      
      final recordingResult = RecordingResult.fromMap(result);
      
      debugPrint('$_tag: Recording started successfully - $recordingResult');
      return recordingResult;
      
    } on PlatformException catch (e) {
      debugPrint('$_tag: Platform exception during recording start: ${e.code} - ${e.message}');
      throw CameraException('Failed to start recording: ${e.message}', code: e.code);
    } catch (e) {
      debugPrint('$_tag: Unexpected error during recording start: $e');
      throw CameraException('Failed to start recording: $e');
    }
  }
  
  /**
   * Stop recording and finalize output
   */
  static Future<RecordingResult> stopRecording() async {
    try {
      debugPrint('$_tag: Stopping recording...');
      
      final result = await _channel.invokeMethod<Map<Object?, Object?>>('stopRecording');
      
      if (result == null) {
        throw Exception('Stop recording returned null');
      }
      
      final recordingResult = RecordingResult.fromMap(result);
      
      debugPrint('$_tag: Recording stopped successfully - $recordingResult');
      return recordingResult;
      
    } on PlatformException catch (e) {
      debugPrint('$_tag: Platform exception during recording stop: ${e.code} - ${e.message}');
      throw CameraException('Failed to stop recording: ${e.message}', code: e.code);
    } catch (e) {
      debugPrint('$_tag: Unexpected error during recording stop: $e');
      throw CameraException('Failed to stop recording: $e');
    }
  }
  
  /**
   * Capture a dual photo with current layout
   */
  static Future<RecordingResult> takeDualPhoto() async {
    try {
      debugPrint('$_tag: Taking dual photo...');
      
      final result = await _channel.invokeMethod<Map<Object?, Object?>>('takeDualPhoto');
      
      if (result == null) {
        throw Exception('Take dual photo returned null');
      }
      
      final photoResult = RecordingResult.fromMap(result);
      
      debugPrint('$_tag: Dual photo captured successfully - $photoResult');
      return photoResult;
      
    } on PlatformException catch (e) {
      debugPrint('$_tag: Platform exception during photo capture: ${e.code} - ${e.message}');
      throw CameraException('Failed to capture photo: ${e.message}', code: e.code);
    } catch (e) {
      debugPrint('$_tag: Unexpected error during photo capture: $e');
      throw CameraException('Failed to capture photo: $e');
    }
  }
  
  /**
   * Get current recording status
   */
  static Future<RecordingStatus> getRecordingStatus() async {
    try {
      debugPrint('$_tag: Getting recording status...');
      
      final result = await _channel.invokeMethod<Map<Object?, Object?>>('getRecordingStatus');
      
      if (result == null) {
        throw Exception('Recording status returned null');
      }
      
      final status = RecordingStatus.fromMap(result);
      
      debugPrint('$_tag: Recording status retrieved - $status');
      return status;
      
    } on PlatformException catch (e) {
      debugPrint('$_tag: Platform exception getting recording status: ${e.code} - ${e.message}');
      // Return default status instead of throwing
      return RecordingStatus(
        isRecording: false,
        layout: 'pip',
        outputFile: '',
        duration: 0.0,
        additionalInfo: {'error': e.message, 'errorCode': e.code},
      );
    } catch (e) {
      debugPrint('$_tag: Unexpected error getting recording status: $e');
      return RecordingStatus(
        isRecording: false,
        layout: 'pip', 
        outputFile: '',
        duration: 0.0,
        additionalInfo: {'error': e.toString()},
      );
    }
  }
  
  // ============================================================
  // INTERACTIVE LAYOUT OPERATIONS  
  // ============================================================
  
  /**
   * Swap camera roles during active recording
   */
  static Future<void> swapCamerasInRecording() async {
    try {
      debugPrint('$_tag: Swapping cameras in recording...');
      
      final result = await _channel.invokeMethod<bool>('swapCamerasInRecording');
      
      if (result == true) {
        debugPrint('$_tag: Camera swap successful');
      } else {
        throw Exception('Camera swap returned false');
      }
      
    } on PlatformException catch (e) {
      debugPrint('$_tag: Platform exception during camera swap: ${e.code} - ${e.message}');
      throw CameraException('Failed to swap cameras: ${e.message}', code: e.code);
    } catch (e) {
      debugPrint('$_tag: Unexpected error during camera swap: $e');
      throw CameraException('Failed to swap cameras: $e');
    }
  }
  
  /**
   * Update recording layout dynamically
   */
  static Future<void> updateRecordingLayout(CameraLayout layout) async {
    try {
      debugPrint('$_tag: Updating recording layout to: $layout...');
      
      final layoutName = _layoutToString(layout);
      
      final result = await _channel.invokeMethod<bool>('updateRecordingLayout', {
        'layout': layoutName,
      });
      
      if (result == true) {
        debugPrint('$_tag: Layout update successful');
      } else {
        throw Exception('Layout update returned false');
      }
      
    } on PlatformException catch (e) {
      debugPrint('$_tag: Platform exception during layout update: ${e.code} - ${e.message}');
      throw CameraException('Failed to update layout: ${e.message}', code: e.code);
    } catch (e) {
      debugPrint('$_tag: Unexpected error during layout update: $e');
      throw CameraException('Failed to update layout: $e');
    }
  }
  
  /**
   * Update PiP coordinates for dynamic positioning
   */
  static Future<void> updatePiPCoordinates(double x, double y, double width, double height) async {
    try {
      debugPrint('$_tag: Updating PiP coordinates: x=$x, y=$y, w=$width, h=$height');
      
      final result = await _channel.invokeMethod<bool>('updatePiPCoordinates', {
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      });
      
      if (result == true) {
        debugPrint('$_tag: PiP coordinate update successful');
      } else {
        throw Exception('PiP coordinate update returned false');
      }
      
    } on PlatformException catch (e) {
      debugPrint('$_tag: Platform exception during PiP update: ${e.code} - ${e.message}');
      throw CameraException('Failed to update PiP coordinates: ${e.message}', code: e.code);
    } catch (e) {
      debugPrint('$_tag: Unexpected error during PiP update: $e');
      throw CameraException('Failed to update PiP coordinates: $e');
    }
  }
  
  // ============================================================
  // HELPER METHODS
  // ============================================================
  
  /**
   * Convert CameraLayout enum to string for native calls
   */
  static String _layoutToString(CameraLayout layout) {
    switch (layout) {
      case CameraLayout.pip:
        return 'pip';
      case CameraLayout.splitVertical:
        return 'splitVertical';
      case CameraLayout.splitHorizontal:
        return 'splitHorizontal';
      case CameraLayout.frontOnly:
        return 'frontOnly';
      case CameraLayout.backOnly:
        return 'backOnly';
    }
  }
}
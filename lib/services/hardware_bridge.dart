import 'package:flutter/services.dart';

/// Hardware Bridge Service
/// Dart wrapper for native hardware detection MethodChannel
/// 
/// Provides a clean interface to the native hardware detection logic
/// with graceful error handling and fallback behavior.
class HardwareBridge {
  static const MethodChannel _channel = MethodChannel('com.example.dual_recorder/hardware_bridge');
  
  /// Check if dual camera streaming is supported on this device
  /// 
  /// Returns:
  /// - `true` if concurrent front/back camera streaming is supported
  /// - `false` if only single camera mode is available
  /// 
  /// Gracefully handles platform exceptions by defaulting to `false`
  static Future<bool> isDualCameraSupported() async {
    try {
      final bool? result = await _channel.invokeMethod('isDualCameraSupported');
      return result ?? false;
    } on PlatformException catch (e) {
      // Graceful degradation - assume single camera only
      print('HardwareBridge: Platform exception in isDualCameraSupported: ${e.message}');
      return false;
    } catch (e) {
      // Any other error - assume single camera only
      print('HardwareBridge: Unexpected error in isDualCameraSupported: $e');
      return false;
    }
  }
  
  /// Get detailed reason why dual camera is not supported
  /// 
  /// Returns:
  /// - `null` if dual camera IS supported
  /// - Human-readable string explaining the limitation if not supported
  /// 
  /// Example reasons:
  /// - "No front camera found"
  /// - "Hardware ISP doesn't support concurrent streaming"
  /// - "Android version too old (requires API 21+)"
  static Future<String?> getDualCameraUnsupportedReason() async {
    try {
      final String? result = await _channel.invokeMethod('getDualCameraUnsupportedReason');
      return result;
    } on PlatformException catch (e) {
      print('HardwareBridge: Platform exception in getDualCameraUnsupportedReason: ${e.message}');
      return 'Hardware detection failed: ${e.message}';
    } catch (e) {
      print('HardwareBridge: Unexpected error in getDualCameraUnsupportedReason: $e');
      return 'Unknown hardware error';
    }
  }
  
  /// Get comprehensive hardware capabilities report
  /// 
  /// Returns a map with detailed device information:
  /// - Camera counts and positions
  /// - Platform version information
  /// - ISP and concurrent streaming capabilities
  /// - Final dual camera support determination
  static Future<Map<String, dynamic>> getHardwareCapabilities() async {
    try {
      final result = await _channel.invokeMethod('getHardwareCapabilities');
      if (result == null) {
        return _getErrorCapabilities('No data returned');
      }
      // Safe type conversion from native Map<Object?, Object?> to Map<String, dynamic>
      final Map<String, dynamic> capabilities = Map<String, dynamic>.from(result);
      return capabilities;
    } on PlatformException catch (e) {
      print('HardwareBridge: Platform exception in getHardwareCapabilities: ${e.message}');
      return _getErrorCapabilities('Platform exception: ${e.message}');
    } catch (e) {
      print('HardwareBridge: Unexpected error in getHardwareCapabilities: $e');
      return _getErrorCapabilities('Unexpected error: $e');
    }
  }
  
  /// Create error capabilities map for fallback scenarios
  static Map<String, dynamic> _getErrorCapabilities(String errorMessage) {
    return {
      'error': true,
      'errorMessage': errorMessage,
      'isDualCameraSupported': false,
      'unsupportedReason': 'Hardware detection failed',
      'totalCameras': 0,
      'hasFrontCamera': false,
      'hasBackCamera': false,
    };
  }
  
  /// Test the MethodChannel connectivity
  /// 
  /// Useful for debugging and connectivity audits.
  /// Returns `true` if the native bridge is responding properly.
  static Future<bool> testConnectivity() async {
    try {
      // Simple test - try to get dual camera support
      await isDualCameraSupported();
      return true;
    } catch (e) {
      print('HardwareBridge: Connectivity test failed: $e');
      return false;
    }
  }
}
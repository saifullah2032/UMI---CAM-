/// Hardware Capabilities Data Model
/// 
/// Represents the device's camera hardware capabilities
/// Used by the CameraCapabilityProvider to expose typed hardware information
class HardwareCapabilities {
  final bool isDualCameraSupported;
  final String? unsupportedReason;
  final int totalCameras;
  final bool hasFrontCamera;
  final bool hasBackCamera;
  final String? deviceModel;
  final String? platformVersion;
  final bool officialConcurrentSupport;
  final bool hasError;
  final String? errorMessage;
  
  const HardwareCapabilities({
    required this.isDualCameraSupported,
    this.unsupportedReason,
    required this.totalCameras,
    required this.hasFrontCamera,
    required this.hasBackCamera,
    this.deviceModel,
    this.platformVersion,
    this.officialConcurrentSupport = false,
    this.hasError = false,
    this.errorMessage,
  });
  
  /// Create HardwareCapabilities from native hardware detection results
  factory HardwareCapabilities.fromMap(Map<String, dynamic> map) {
    return HardwareCapabilities(
      isDualCameraSupported: map['isDualCameraSupported'] as bool? ?? false,
      unsupportedReason: map['unsupportedReason'] as String?,
      totalCameras: map['totalCameras'] as int? ?? 0,
      hasFrontCamera: map['hasFrontCamera'] as bool? ?? false,
      hasBackCamera: map['hasBackCamera'] as bool? ?? false,
      deviceModel: map['deviceModel'] as String? ?? map['deviceName'] as String?,
      platformVersion: map['androidVersion']?.toString() ?? map['iOSVersion'] as String?,
      officialConcurrentSupport: map['officialConcurrentSupport'] as bool? ?? 
                                map['officialMultiCamSupport'] as bool? ?? false,
      hasError: map['error'] as bool? ?? false,
      errorMessage: map['errorMessage'] as String?,
    );
  }
  
  /// Create error state capabilities
  factory HardwareCapabilities.error(String message) {
    return HardwareCapabilities(
      isDualCameraSupported: false,
      unsupportedReason: 'Hardware detection failed',
      totalCameras: 0,
      hasFrontCamera: false,
      hasBackCamera: false,
      hasError: true,
      errorMessage: message,
    );
  }
  
  /// Create loading state capabilities
  factory HardwareCapabilities.loading() {
    return const HardwareCapabilities(
      isDualCameraSupported: false,
      unsupportedReason: 'Checking hardware capabilities...',
      totalCameras: 0,
      hasFrontCamera: false,
      hasBackCamera: false,
    );
  }
  
  /// Get user-friendly system status text for the UI plaque
  String get systemStatusText {
    if (hasError) {
      return 'SYSTEM ERROR: DETECTION FAILED';
    }
    
    if (isDualCameraSupported) {
      return 'SYSTEM READY: DUAL CAM OK';
    } else {
      return 'SYSTEM READY: SINGLE CAM ONLY';
    }
  }
  
  /// Get detailed status for debugging
  String get detailedStatus {
    if (hasError) {
      return 'Error: $errorMessage';
    }
    
    if (isDualCameraSupported) {
      return 'Dual camera supported ($totalCameras cameras detected)';
    } else {
      return unsupportedReason ?? 'Single camera mode only';
    }
  }
  
  /// Check if device has basic camera functionality
  bool get hasAnyCameras => hasFrontCamera || hasBackCamera;
  
  /// Check if device has adequate cameras for the app
  bool get meetsMinimumRequirements => hasAnyCameras;
  
  @override
  String toString() {
    return 'HardwareCapabilities(isDualSupported: $isDualCameraSupported, '
           'totalCameras: $totalCameras, reason: $unsupportedReason)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HardwareCapabilities &&
           other.isDualCameraSupported == isDualCameraSupported &&
           other.unsupportedReason == unsupportedReason &&
           other.totalCameras == totalCameras &&
           other.hasFrontCamera == hasFrontCamera &&
           other.hasBackCamera == hasBackCamera;
  }
  
  @override
  int get hashCode {
    return Object.hash(
      isDualCameraSupported,
      unsupportedReason,
      totalCameras,
      hasFrontCamera,
      hasBackCamera,
    );
  }
}
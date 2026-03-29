import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/hardware_bridge.dart';
import '../models/hardware_capabilities.dart';

/// Camera Capability Provider
/// 
/// Manages hardware detection state using ChangeNotifier pattern.
/// Provides reactive hardware capability information to the UI.
/// 
/// Usage:
/// - Automatically detects hardware on initialization
/// - Exposes `isSupported`, `reason`, `isLoading` for UI consumption
/// - Notifies listeners when detection completes or fails
class CameraCapabilityProvider with ChangeNotifier {
  
  // Private state
  HardwareCapabilities _capabilities = HardwareCapabilities.loading();
  bool _isLoading = true;
  String? _lastError;
  
  // Permission state
  bool _permissionsGranted = false;
  bool _permissionCheckInProgress = false;
  Map<String, PermissionStatus> _permissionStatuses = {};
  
  // Public getters for UI consumption
  
  /// Whether dual camera streaming is supported on this device
  bool get isDualCameraSupported => _capabilities.isDualCameraSupported;
  
  /// Human-readable reason why dual camera is not supported (null if supported)
  String? get unsupportedReason => _capabilities.unsupportedReason;
  
  /// Whether hardware detection is currently in progress
  bool get isLoading => _isLoading;
  
  /// Complete hardware capabilities object
  HardwareCapabilities get capabilities => _capabilities;
  
  /// System status text for the UI plaque
  String get systemStatusText => _capabilities.systemStatusText;
  
  /// Whether the app can function (has at least one camera)
  bool get canFunctionBasically => _capabilities.meetsMinimumRequirements;
  
  /// Last error message if detection failed
  String? get lastError => _lastError;
  
  /// Whether an error occurred during detection
  bool get hasError => _capabilities.hasError || _lastError != null;
  
  /// Whether all required permissions are granted
  bool get permissionsGranted => _permissionsGranted;
  
  /// Whether permission check is in progress
  bool get permissionCheckInProgress => _permissionCheckInProgress;
  
  /// Current permission statuses
  Map<String, PermissionStatus> get permissionStatuses => Map.from(_permissionStatuses);
  
  /// Whether the app is ready (permissions granted and capabilities detected)
  bool get isAppReady => _permissionsGranted && !_isLoading && !hasError;
  
  /// Initialize and perform hardware detection
  /// 
  /// Hardware detection will be triggered after permissions are granted.
  /// Call requestInitialPermissions() first.
  CameraCapabilityProvider() {
    // Don't automatically start hardware detection - wait for permissions
    print('CameraCapabilityProvider: Initialized - waiting for permission grant before hardware detection');
  }
  
  /// Request all required permissions for the app
  /// 
  /// Must be called before hardware detection and camera initialization.
  /// Requests Camera, Microphone, and Media Library (Photos) permissions.
  /// 
  /// Returns true if all permissions are granted, false otherwise.
  Future<bool> requestInitialPermissions() async {
    try {
      _permissionCheckInProgress = true;
      notifyListeners();
      
      print('CameraCapabilityProvider: Requesting initial permissions...');
      
      // Define required permissions
      final List<Permission> requiredPermissions = [
        Permission.camera,
        Permission.microphone,
        Permission.photos, // Media Library access
      ];
      
      // Check current status of all permissions
      _permissionStatuses.clear();
      for (final permission in requiredPermissions) {
        _permissionStatuses[_getPermissionName(permission)] = await permission.status;
      }
      
      print('CameraCapabilityProvider: Current permission statuses:');
      _permissionStatuses.forEach((name, status) {
        print('  - $name: $status');
      });
      
      // Request all permissions at once
      final Map<Permission, PermissionStatus> results = await requiredPermissions.request();
      
      // Update statuses with results
      for (final entry in results.entries) {
        _permissionStatuses[_getPermissionName(entry.key)] = entry.value;
      }
      
      print('CameraCapabilityProvider: Permission request results:');
      _permissionStatuses.forEach((name, status) {
        print('  - $name: $status');
      });
      
      // Check if all required permissions are granted
      _permissionsGranted = results.values.every((status) => status == PermissionStatus.granted);
      
      if (_permissionsGranted) {
        print('CameraCapabilityProvider: ✅ All permissions granted - proceeding with hardware detection');
        // Start hardware detection now that permissions are granted
        await _initializeHardwareDetection();
      } else {
        print('CameraCapabilityProvider: ❌ Some permissions denied - app cannot function');
        final deniedPermissions = results.entries
            .where((entry) => entry.value != PermissionStatus.granted)
            .map((entry) => _getPermissionName(entry.key))
            .toList();
        print('CameraCapabilityProvider: Denied permissions: ${deniedPermissions.join(", ")}');
      }
      
      return _permissionsGranted;
      
    } catch (e) {
      print('CameraCapabilityProvider: Permission request failed: $e');
      _lastError = 'Permission request failed: $e';
      _permissionsGranted = false;
      return false;
    } finally {
      _permissionCheckInProgress = false;
      notifyListeners();
    }
  }
  
  /// Get human-readable permission name
  String _getPermissionName(Permission permission) {
    switch (permission) {
      case Permission.camera:
        return 'Camera';
      case Permission.microphone:
        return 'Microphone';
      case Permission.photos:
        return 'Media Library';
      default:
        return permission.toString();
    }
  }
  
  /// Check if we can request permission (not permanently denied)
  Future<bool> canRequestPermission(Permission permission) async {
    final status = await permission.status;
    return status != PermissionStatus.permanentlyDenied;
  }
  
  /// Open app settings for manual permission grant
  Future<bool> openDeviceSettings() async {
    try {
      print('CameraCapabilityProvider: Opening device settings...');
      return await openAppSettings();
    } catch (e) {
      print('CameraCapabilityProvider: Failed to open device settings: $e');
      return false;
    }
  }
  
  /// Perform hardware detection and update state
  Future<void> _initializeHardwareDetection() async {
    try {
      _isLoading = true;
      _lastError = null;
      notifyListeners();
      
      print('CameraCapabilityProvider: Starting hardware detection...');
      
      // Get comprehensive hardware capabilities from native bridge
      final capabilitiesMap = await HardwareBridge.getHardwareCapabilities();
      
      // Convert to typed model
      _capabilities = HardwareCapabilities.fromMap(capabilitiesMap);
      
      print('CameraCapabilityProvider: Detection complete - ${_capabilities.detailedStatus}');
      
    } catch (e) {
      print('CameraCapabilityProvider: Hardware detection failed: $e');
      _lastError = e.toString();
      _capabilities = HardwareCapabilities.error('Detection failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Manually refresh hardware detection
  /// 
  /// Useful for retry functionality or when hardware state might have changed
  Future<void> refreshCapabilities() async {
    print('CameraCapabilityProvider: Manual refresh requested');
    await _initializeHardwareDetection();
  }
  
  /// Test connectivity to native hardware bridge
  /// 
  /// Returns true if the MethodChannel is working properly
  Future<bool> testConnectivity() async {
    try {
      return await HardwareBridge.testConnectivity();
    } catch (e) {
      print('CameraCapabilityProvider: Connectivity test failed: $e');
      return false;
    }
  }
  
  /// Get user-friendly capability summary for debugging
  String getCapabilitySummary() {
    if (_isLoading) {
      return 'Hardware detection in progress...';
    }
    
    if (hasError) {
      return 'Error: ${_lastError ?? _capabilities.errorMessage ?? 'Unknown error'}';
    }
    
    final buffer = StringBuffer();
    buffer.writeln('📱 Device: ${_capabilities.deviceModel ?? 'Unknown'}');
    buffer.writeln('🔢 Total Cameras: ${_capabilities.totalCameras}');
    buffer.writeln('📷 Front Camera: ${_capabilities.hasFrontCamera ? '✅' : '❌'}');
    buffer.writeln('📷 Back Camera: ${_capabilities.hasBackCamera ? '✅' : '❌'}');
    buffer.writeln('🎥 Dual Camera: ${_capabilities.isDualCameraSupported ? '✅' : '❌'}');
    
    if (!_capabilities.isDualCameraSupported && _capabilities.unsupportedReason != null) {
      buffer.writeln('⚠️ Reason: ${_capabilities.unsupportedReason}');
    }
    
    return buffer.toString();
  }
  
  /// Debug information for troubleshooting
  Map<String, dynamic> getDebugInfo() {
    return {
      'isLoading': _isLoading,
      'isDualCameraSupported': _capabilities.isDualCameraSupported,
      'unsupportedReason': _capabilities.unsupportedReason,
      'totalCameras': _capabilities.totalCameras,
      'hasFrontCamera': _capabilities.hasFrontCamera,
      'hasBackCamera': _capabilities.hasBackCamera,
      'deviceModel': _capabilities.deviceModel,
      'platformVersion': _capabilities.platformVersion,
      'officialConcurrentSupport': _capabilities.officialConcurrentSupport,
      'hasError': _capabilities.hasError,
      'errorMessage': _capabilities.errorMessage,
      'lastError': _lastError,
      'systemStatusText': _capabilities.systemStatusText,
    };
  }
}
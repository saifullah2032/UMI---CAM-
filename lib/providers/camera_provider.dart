import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/native_camera_service.dart';

/**
 * CameraProvider - Manages dual camera session state and operations
 * 
 * Reactive state management for the camera system using ChangeNotifier.
 * Handles initialization, opening/closing cameras, and state monitoring.
 */
class CameraProvider extends ChangeNotifier {
  static const String _tag = 'CameraProvider';
  
  // Initialization state
  bool _isInitialized = false;
  bool _isInitializing = false;
  
  // Camera session state
  bool _isCamerasOpen = false;
  bool _isOpeningCameras = false;
  
  // Texture IDs for Flutter preview widgets
  int _frontTextureId = -1;
  int _backTextureId = -1;
  
  // Preview dimensions
  int _previewWidth = 1280;
  int _previewHeight = 720;
  
  // Error handling
  bool _hasError = false;
  String? _errorMessage;
  
  // Current layout mode
  CameraLayout _currentLayout = CameraLayout.pip;
  
  // Camera swap state
  bool _camerasSwapped = false;
  
  // PiP coordinate tracking for native recording
  Rect _pipRect = const Rect.fromLTWH(20, 100, 120, 160);
  
  // Recording state
  bool _isRecordingInitialized = false;
  bool _isRecording = false;
  bool _isStartingRecording = false;
  bool _isStoppingRecording = false;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;
  Timer? _recordingTimer;
  
  // Status monitoring timer
  Timer? _statusTimer;
  
  // ============================================================
  // PUBLIC GETTERS
  // ============================================================
  
  /// Whether the camera system is initialized
  bool get isInitialized => _isInitialized;
  
  /// Whether initialization is in progress
  bool get isInitializing => _isInitializing;
  
  /// Whether cameras are currently open and streaming
  bool get isCamerasOpen => _isCamerasOpen;
  
  /// Whether camera opening is in progress
  bool get isOpeningCameras => _isOpeningCameras;
  
  /// Front camera texture ID for Flutter Texture widget
  int get frontTextureId => _frontTextureId;
  
  /// Back camera texture ID for Flutter Texture widget
  int get backTextureId => _backTextureId;
  
  /// Preview width in pixels
  int get previewWidth => _previewWidth;
  
  /// Preview height in pixels
  int get previewHeight => _previewHeight;
  
  /// Whether an error has occurred
  bool get hasError => _hasError;
  
  /// Current error message (if any)
  String? get errorMessage => _errorMessage;
  
  /// Current camera layout mode
  CameraLayout get currentLayout => _currentLayout;
  
  /// Whether cameras are swapped (front/back roles reversed)
  bool get camerasSwapped => _camerasSwapped;
  
  /// Current PiP window rectangle for coordinate tracking
  Rect get pipRect => _pipRect;
  
  /// Primary camera texture ID (depends on swap state)
  int get primaryTextureId => _camerasSwapped ? _frontTextureId : _backTextureId;
  
  /// Secondary camera texture ID (depends on swap state)
  int get secondaryTextureId => _camerasSwapped ? _backTextureId : _frontTextureId;
  
  /// Whether any camera operations are in progress
  bool get isLoading => _isInitializing || _isOpeningCameras || _isStartingRecording || _isStoppingRecording;
  
  // ============================================================
  // RECORDING STATE GETTERS
  // ============================================================
  
  /// Whether the recording system is initialized
  bool get isRecordingInitialized => _isRecordingInitialized;
  
  /// Whether recording is currently active
  bool get isRecording => _isRecording;
  
  /// Whether recording start is in progress
  bool get isStartingRecording => _isStartingRecording;
  
  /// Whether recording stop is in progress
  bool get isStoppingRecording => _isStoppingRecording;
  
  /// Current recording file path (if recording)
  String? get currentRecordingPath => _currentRecordingPath;
  
  /// Recording duration (if recording)
  Duration get recordingDuration {
    if (!_isRecording || _recordingStartTime == null) {
      return Duration.zero;
    }
    return DateTime.now().difference(_recordingStartTime!);
  }
  
  /// Whether the system is ready to start recording
  bool get isReadyForRecording => _isInitialized && _isCamerasOpen && !_hasError && _isRecordingInitialized;
  
  // ============================================================
  // PERMISSION HANDLING
  // ============================================================
  
  /**
   * Request camera and microphone permissions
   * Must be called before any camera initialization
   */
  Future<bool> requestPermissions() async {
    try {
      debugPrint('$_tag: Requesting camera and microphone permissions...');
      
      // Request both permissions
      final Map<Permission, PermissionStatus> permissions = await [
        Permission.camera,
        Permission.microphone,
      ].request();
      
      final cameraStatus = permissions[Permission.camera];
      final microphoneStatus = permissions[Permission.microphone];
      
      debugPrint('$_tag: Camera permission: $cameraStatus');
      debugPrint('$_tag: Microphone permission: $microphoneStatus');
      
      // Both permissions must be granted
      final bool granted = cameraStatus == PermissionStatus.granted && 
                          microphoneStatus == PermissionStatus.granted;
      
      if (!granted) {
        final deniedPermissions = <String>[];
        if (cameraStatus != PermissionStatus.granted) deniedPermissions.add('Camera');
        if (microphoneStatus != PermissionStatus.granted) deniedPermissions.add('Microphone');
        
        final errorMsg = 'Required permissions denied: ${deniedPermissions.join(', ')}';
        debugPrint('$_tag: $errorMsg');
        _setError(errorMsg);
      }
      
      return granted;
      
    } catch (e) {
      debugPrint('$_tag: Permission request failed: $e');
      _setError('Permission request failed: $e');
      return false;
    }
  }
  
  /**
   * Check if camera and microphone permissions are currently granted
   */
  Future<bool> checkPermissions() async {
    try {
      final cameraStatus = await Permission.camera.status;
      final microphoneStatus = await Permission.microphone.status;
      
      debugPrint('$_tag: Checking permissions - Camera: $cameraStatus, Microphone: $microphoneStatus');
      
      return cameraStatus == PermissionStatus.granted && 
             microphoneStatus == PermissionStatus.granted;
             
    } catch (e) {
      debugPrint('$_tag: Permission check failed: $e');
      return false;
    }
  }
  
  // ============================================================
  // CAMERA OPERATIONS
  // ============================================================
  
  /**
   * Initialize the dual camera system
   * Creates texture entries and prepares for camera operations
   */
  Future<void> initializeCameras() async {
    if (_isInitialized || _isInitializing) {
      debugPrint('$_tag: Camera already initialized or initializing');
      return;
    }
    
    _isInitializing = true;
    _clearError();
    // Defer notification to avoid build phase race condition
    Future.microtask(() => notifyListeners());
    
    try {
      debugPrint('$_tag: Starting camera initialization...');
      
      // Step 1: Request permissions first
      final bool permissionsGranted = await requestPermissions();
      if (!permissionsGranted) {
        debugPrint('$_tag: Cannot initialize cameras - permissions denied');
        return; // Error already set in requestPermissions()
      }
      
      debugPrint('$_tag: Permissions granted, proceeding with camera initialization...');
      
      // Step 2: Initialize native camera system
      final result = await NativeCameraService.initializeCameras();
      
      _frontTextureId = result.frontTextureId;
      _backTextureId = result.backTextureId;
      _previewWidth = result.previewWidth;
      _previewHeight = result.previewHeight;
      
      _isInitialized = true;
      
      debugPrint('$_tag: Camera initialization successful');
      debugPrint('$_tag: Front texture ID: $_frontTextureId');
      debugPrint('$_tag: Back texture ID: $_backTextureId');
      debugPrint('$_tag: Preview size: ${_previewWidth}x$_previewHeight');
      
      // Step 3: Automatically open cameras after successful initialization
      debugPrint('$_tag: Proceeding to open cameras...');
      await _openCamerasAfterInit();
      
    } catch (e) {
      debugPrint('$_tag: Camera initialization failed: $e');
      _setError('Camera initialization failed: $e');
    } finally {
      _isInitializing = false;
      // Defer notification to avoid build phase race condition
      Future.microtask(() => notifyListeners());
    }
  }
  
  /**
   * Open both cameras and start streaming
   * 
   * @param bypassMode - Attempt dual camera even if not officially supported
   */
  Future<void> openCameras({bool bypassMode = false}) async {
    if (!_isInitialized) {
      debugPrint('$_tag: Cannot open cameras - not initialized');
      _setError('Cannot open cameras: system not initialized');
      return;
    }
    
    if (_isCamerasOpen || _isOpeningCameras) {
      debugPrint('$_tag: Cameras already open or opening');
      return;
    }
    
    _isOpeningCameras = true;
    _clearError();
    notifyListeners();
    
    try {
      debugPrint('$_tag: Opening cameras (bypassMode: $bypassMode)...');
      
      await NativeCameraService.openCameras(bypassMode: bypassMode);
      
      _isCamerasOpen = true;
      
      // Start status monitoring
      _startStatusMonitoring();
      
      debugPrint('$_tag: Cameras opened successfully');
      
    } catch (e) {
      debugPrint('$_tag: Failed to open cameras: $e');
      _setError('Failed to open cameras: $e');
    } finally {
      _isOpeningCameras = false;
      notifyListeners();
    }
  }
  
  /**
   * Close cameras and stop streaming
   */
  Future<void> closeCameras() async {
    if (!_isCamerasOpen) {
      debugPrint('$_tag: Cameras already closed');
      return;
    }
    
    try {
      debugPrint('$_tag: Closing cameras...');
      
      // Stop status monitoring
      _stopStatusMonitoring();
      
      await NativeCameraService.closeCameras();
      
      _isCamerasOpen = false;
      
      debugPrint('$_tag: Cameras closed successfully');
      
    } catch (e) {
      debugPrint('$_tag: Failed to close cameras: $e');
      _setError('Failed to close cameras: $e');
    } finally {
      notifyListeners();
    }
  }
  
  /**
   * Switch between camera layout modes
   */
  void setLayout(CameraLayout layout) {
    if (_currentLayout != layout) {
      _currentLayout = layout;
      debugPrint('$_tag: Layout changed to: $layout');
      
      // Send layout update to native recording system if recording
      if (_isRecording) {
        _updateNativeLayout();
      }
      
      notifyListeners();
    }
  }
  
  /**
   * Swap front and back camera roles
   * Primary becomes secondary and vice versa
   */
  Future<void> swapCameras() async {
    if (!_isInitialized || !_isCamerasOpen) {
      debugPrint('$_tag: Cannot swap cameras - system not ready');
      return;
    }
    
    try {
      debugPrint('$_tag: Swapping camera roles...');
      
      // Toggle swap state
      _camerasSwapped = !_camerasSwapped;
      
      debugPrint('$_tag: Cameras swapped - now ${_camerasSwapped ? "SWAPPED" : "NORMAL"}');
      debugPrint('$_tag: Primary camera: ${_camerasSwapped ? "Front" : "Back"}');
      debugPrint('$_tag: Secondary camera: ${_camerasSwapped ? "Back" : "Front"}');
      
      // Notify native recording system if recording
      if (_isRecording) {
        await NativeCameraService.swapCamerasInRecording();
        debugPrint('$_tag: Native camera swap completed');
      }
      
      notifyListeners();
      
    } catch (e) {
      debugPrint('$_tag: Camera swap failed: $e');
      _setError('Camera swap failed: $e');
    }
  }
  
  /**
   * Update PiP window coordinates for native recording system
   */
  void updatePiPRect(Rect rect) {
    if (_pipRect != rect) {
      _pipRect = rect;
      
      debugPrint('$_tag: PiP coordinates updated: ${rect.left}, ${rect.top}, ${rect.width}, ${rect.height}');
      
      // Send coordinates to native recording system if recording
      if (_isRecording && _currentLayout == CameraLayout.pip) {
        _updateNativePiPCoordinates();
      }
      
      // No need to notify listeners - this is for recording coordination only
    }
  }
  
  /**
   * Get layout preset positions for smooth transitions
   */
  Rect getLayoutPresetRect(CameraLayout layout, Size screenSize) {
    switch (layout) {
      case CameraLayout.pip:
        // Default PiP position (top-right corner)
        return Rect.fromLTWH(
          screenSize.width - 140,
          100,
          120,
          160,
        );
      case CameraLayout.splitVertical:
      case CameraLayout.splitHorizontal:
        // Split layouts don't use PiP
        return Rect.zero;
      case CameraLayout.frontOnly:
      case CameraLayout.backOnly:
        // Single camera layouts don't use PiP
        return Rect.zero;
    }
  }
  
  // ============================================================
  // PRIVATE NATIVE COORDINATION METHODS
  // ============================================================
  
  /**
   * Send current layout to native recording system
   */
  Future<void> _updateNativeLayout() async {
    try {
      await NativeCameraService.updateRecordingLayout(_currentLayout);
      debugPrint('$_tag: Native layout updated to: $_currentLayout');
    } catch (e) {
      debugPrint('$_tag: Failed to update native layout: $e');
    }
  }
  
  /**
   * Send PiP coordinates to native recording system
   * Converts Flutter screen coordinates (1920x1080 reference) to normalized recording coordinates
   */
  Future<void> _updateNativePiPCoordinates() async {
    try {
      // Convert Flutter UI coordinates to normalized video coordinates (0.0 to 1.0)
      // Assuming Flutter screen reference of 1920x1080 for coordinate normalization
      const double referenceWidth = 1920.0;
      const double referenceHeight = 1080.0;
      
      final double normalizedX = _pipRect.left / referenceWidth;
      final double normalizedY = _pipRect.top / referenceHeight;
      final double normalizedWidth = _pipRect.width / referenceWidth;
      final double normalizedHeight = _pipRect.height / referenceHeight;
      
      await NativeCameraService.updatePiPCoordinates(
        normalizedX.clamp(0.0, 1.0),
        normalizedY.clamp(0.0, 1.0),
        normalizedWidth.clamp(0.0, 1.0),
        normalizedHeight.clamp(0.0, 1.0),
      );
      
      debugPrint('$_tag: Native PiP coordinates updated: x=$normalizedX, y=$normalizedY, w=$normalizedWidth, h=$normalizedHeight');
    } catch (e) {
      debugPrint('$_tag: Failed to update native PiP coordinates: $e');
    }
  }
  
  // ============================================================
  // RECORDING OPERATIONS
  // ============================================================
  
  /**
   * Initialize the recording system
   */
  Future<void> initializeRecording() async {
    if (_isRecordingInitialized) {
      debugPrint('$_tag: Recording already initialized');
      return;
    }
    
    if (!_isInitialized || !_isCamerasOpen) {
      debugPrint('$_tag: Cannot initialize recording - cameras not ready');
      _setError('Cannot initialize recording: cameras not ready');
      return;
    }
    
    try {
      debugPrint('$_tag: Initializing recording system...');
      
      await NativeCameraService.initializeRecording();
      
      _isRecordingInitialized = true;
      _clearError();
      
      debugPrint('$_tag: Recording system initialized successfully');
      
    } catch (e) {
      debugPrint('$_tag: Recording initialization failed: $e');
      _setError('Recording initialization failed: $e');
    } finally {
      notifyListeners();
    }
  }
  
  /**
   * Start recording with the current layout
   */
  Future<void> startRecording() async {
    if (!isReadyForRecording) {
      debugPrint('$_tag: Cannot start recording - system not ready');
      _setError('Cannot start recording: system not ready');
      return;
    }
    
    if (_isRecording || _isStartingRecording) {
      debugPrint('$_tag: Recording already active or starting');
      return;
    }
    
    _isStartingRecording = true;
    _clearError();
    notifyListeners();
    
    try {
      debugPrint('$_tag: Starting recording with layout: $_currentLayout');
      
      final result = await NativeCameraService.startRecording(_currentLayout);
      
      _isRecording = true;
      _currentRecordingPath = result.filePath;
      _recordingStartTime = DateTime.now();
      
      // Start recording timer for UI updates
      _startRecordingTimer();
      
      debugPrint('$_tag: Recording started successfully');
      debugPrint('$_tag: Output file: $_currentRecordingPath');
      
    } catch (e) {
      debugPrint('$_tag: Failed to start recording: $e');
      _setError('Failed to start recording: $e');
    } finally {
      _isStartingRecording = false;
      notifyListeners();
    }
  }
  
  /**
   * Stop recording and finalize the output
   */
  Future<String?> stopRecording() async {
    if (!_isRecording) {
      debugPrint('$_tag: No recording in progress');
      return null;
    }
    
    if (_isStoppingRecording) {
      debugPrint('$_tag: Recording stop already in progress');
      return null;
    }
    
    _isStoppingRecording = true;
    notifyListeners();
    
    try {
      debugPrint('$_tag: Stopping recording...');
      
      _stopRecordingTimer();
      
      final result = await NativeCameraService.stopRecording();
      
      final filePath = result.filePath;
      final duration = recordingDuration;
      
      // Reset recording state
      _isRecording = false;
      _currentRecordingPath = null;
      _recordingStartTime = null;
      
      debugPrint('$_tag: Recording stopped successfully');
      debugPrint('$_tag: Duration: ${duration.inSeconds}s');
      debugPrint('$_tag: Output: $filePath');
      
      return filePath;
      
    } catch (e) {
      debugPrint('$_tag: Failed to stop recording: $e');
      _setError('Failed to stop recording: $e');
      return null;
    } finally {
      _isStoppingRecording = false;
      notifyListeners();
    }
  }
  
  /**
   * Capture a dual photo with current layout
   */
  Future<String?> takeDualPhoto() async {
    if (!_isInitialized || !_isCamerasOpen) {
      debugPrint('$_tag: Cannot take photo - cameras not ready');
      _setError('Cannot take photo: cameras not ready');
      return null;
    }
    
    try {
      debugPrint('$_tag: Taking dual photo...');
      
      final result = await NativeCameraService.takeDualPhoto();
      
      debugPrint('$_tag: Dual photo captured: ${result.filePath}');
      return result.filePath;
      
    } catch (e) {
      debugPrint('$_tag: Failed to take dual photo: $e');
      _setError('Failed to take dual photo: $e');
      return null;
    }
  }
  
  /**
   * Refresh camera status from native code
   */
  Future<void> refreshStatus() async {
    try {
      final status = await NativeCameraService.getCameraStatus();
      
      // Update state based on native status
      final wasOpen = _isCamerasOpen;
      _isCamerasOpen = status.isCamerasOpen;
      
      // Check for unexpected state changes
      if (wasOpen != _isCamerasOpen) {
        debugPrint('$_tag: Camera state changed unexpectedly - was: $wasOpen, now: $_isCamerasOpen');
        notifyListeners();
      }
      
      // Check for errors in native status
      if (status.additionalInfo.containsKey('error')) {
        final error = status.additionalInfo['error'];
        debugPrint('$_tag: Native status reports error: $error');
        _setError('Native camera error: $error');
      }
      
    } catch (e) {
      debugPrint('$_tag: Failed to refresh camera status: $e');
    }
  }
  
  // ============================================================
  // PRIVATE HELPERS
  // ============================================================
  
  void _setError(String message) {
    _hasError = true;
    _errorMessage = message;
    notifyListeners();
  }
  
  void _clearError() {
    _hasError = false;
    _errorMessage = null;
  }
  
  void _startRecordingTimer() {
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Trigger UI update every second during recording
      notifyListeners();
    });
    
    debugPrint('$_tag: Started recording timer');
  }
  
  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    debugPrint('$_tag: Stopped recording timer');
  }
  
  void _startStatusMonitoring() {
    _stopStatusMonitoring(); // Ensure no duplicate timers
    
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      refreshStatus();
    });
    
    debugPrint('$_tag: Started status monitoring');
  }
  
  void _stopStatusMonitoring() {
    _statusTimer?.cancel();
    _statusTimer = null;
    debugPrint('$_tag: Stopped status monitoring');
  }
  
  @override
  void dispose() {
    debugPrint('$_tag: Disposing CameraProvider...');
    
    _stopStatusMonitoring();
    
    // Close cameras if open (fire-and-forget)
    if (_isCamerasOpen) {
      closeCameras();
    }
    
    super.dispose();
  }
  
  // ============================================================
  // DEBUGGING
  // ============================================================
  
  /**
   * Get comprehensive status information for debugging
   */
  Map<String, dynamic> getDebugInfo() {
    return {
      'isInitialized': _isInitialized,
      'isInitializing': _isInitializing,
      'isCamerasOpen': _isCamerasOpen,
      'isOpeningCameras': _isOpeningCameras,
      'frontTextureId': _frontTextureId,
      'backTextureId': _backTextureId,
      'previewSize': '${_previewWidth}x$_previewHeight',
      'hasError': _hasError,
      'errorMessage': _errorMessage,
      'currentLayout': _currentLayout.toString(),
      'isReadyForRecording': isReadyForRecording,
      'isLoading': isLoading,
      'platformSupported': NativeCameraService.isSupported,
      'platformInfo': NativeCameraService.platformInfo,
    };
  }
  
  /**
   * Internal method to open cameras after successful initialization
   * This ensures a smooth initialization → opening flow
   */
  Future<void> _openCamerasAfterInit() async {
    try {
      debugPrint('$_tag: Opening cameras after initialization...');
      
      // Use the public openCameras method with bypass mode for maximum compatibility
      await openCameras(bypassMode: true);
      
      debugPrint('$_tag: Camera opening after init completed');
      
    } catch (e) {
      debugPrint('$_tag: Failed to open cameras after init: $e');
      _setError('Failed to open cameras: $e');
    }
  }
  
  @override
  String toString() {
    return 'CameraProvider(init: $_isInitialized, open: $_isCamerasOpen, error: $_hasError, layout: $_currentLayout)';
  }
}
  
  /**
 * Camera layout modes for dual preview
 */
enum CameraLayout {
  /// Picture-in-Picture: Back camera fullscreen, front camera in corner
  pip,
  /// Vertical Split: Back camera left, front camera right
  splitVertical,
  /// Horizontal Split: Back camera top, front camera bottom
  splitHorizontal,
  /// Front camera only
  frontOnly,
  /// Back camera only  
  backOnly,
}

extension CameraLayoutExtension on CameraLayout {
  String get displayName {
    switch (this) {
      case CameraLayout.pip:
        return 'Picture in Picture';
      case CameraLayout.splitVertical:
        return 'Vertical Split';
      case CameraLayout.splitHorizontal:
        return 'Horizontal Split';
      case CameraLayout.frontOnly:
        return 'Front Camera Only';
      case CameraLayout.backOnly:
        return 'Back Camera Only';
    }
  }
  
  String get shortName {
    switch (this) {
      case CameraLayout.pip:
        return 'PiP';
      case CameraLayout.splitVertical:
        return 'V-Split';
      case CameraLayout.splitHorizontal:
        return 'H-Split';
      case CameraLayout.frontOnly:
        return 'Front';
      case CameraLayout.backOnly:
        return 'Back';
    }
  }
  
  IconData get icon {
    switch (this) {
      case CameraLayout.pip:
        return Icons.picture_in_picture_alt;
      case CameraLayout.splitVertical:
        return Icons.view_column;
      case CameraLayout.splitHorizontal:
        return Icons.view_agenda;
      case CameraLayout.frontOnly:
        return Icons.camera_front;
      case CameraLayout.backOnly:
        return Icons.camera_rear;
    }
  }
}
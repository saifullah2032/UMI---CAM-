import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/**
 * Video Quality enumeration with bitrate and resolution settings
 */
enum VideoQuality {
  low,
  medium,
  high,
}

extension VideoQualityExtension on VideoQuality {
  String get displayName {
    switch (this) {
      case VideoQuality.low:
        return 'LOW';
      case VideoQuality.medium:
        return 'MED';
      case VideoQuality.high:
        return 'HIGH';
    }
  }

  String get description {
    switch (this) {
      case VideoQuality.low:
        return '480p @ 2Mbps';
      case VideoQuality.medium:
        return '720p @ 5Mbps';
      case VideoQuality.high:
        return '1080p @ 10Mbps';
    }
  }

  /// Get video width in pixels
  int get width {
    switch (this) {
      case VideoQuality.low:
        return 854;
      case VideoQuality.medium:
        return 1280;
      case VideoQuality.high:
        return 1920;
    }
  }

  /// Get video height in pixels
  int get height {
    switch (this) {
      case VideoQuality.low:
        return 480;
      case VideoQuality.medium:
        return 720;
      case VideoQuality.high:
        return 1080;
    }
  }

  /// Get video bitrate in bits per second
  int get bitrate {
    switch (this) {
      case VideoQuality.low:
        return 2_000_000; // 2 Mbps
      case VideoQuality.medium:
        return 5_000_000; // 5 Mbps
      case VideoQuality.high:
        return 10_000_000; // 10 Mbps
    }
  }

  /// Convert from string value (for SharedPreferences)
  static VideoQuality fromString(String value) {
    switch (value.toLowerCase()) {
      case 'low':
        return VideoQuality.low;
      case 'medium':
        return VideoQuality.medium;
      case 'high':
        return VideoQuality.high;
      default:
        return VideoQuality.medium; // Default fallback
    }
  }

  /// Convert to string value (for SharedPreferences)
  String get stringValue {
    return toString().split('.').last;
  }
}

/**
 * Default Layout enumeration for camera layout persistence
 */
enum DefaultLayout {
  pip,
  sideBySide,
}

extension DefaultLayoutExtension on DefaultLayout {
  String get displayName {
    switch (this) {
      case DefaultLayout.pip:
        return 'Picture-in-Picture';
      case DefaultLayout.sideBySide:
        return 'Side-by-Side';
    }
  }

  String get shortName {
    switch (this) {
      case DefaultLayout.pip:
        return 'PiP';
      case DefaultLayout.sideBySide:
        return 'Split';
    }
  }

  /// Convert from string value (for SharedPreferences)
  static DefaultLayout fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pip':
        return DefaultLayout.pip;
      case 'sidebyside':
      case 'split':
        return DefaultLayout.sideBySide;
      default:
        return DefaultLayout.pip; // Default fallback
    }
  }

  /// Convert to string value (for SharedPreferences)
  String get stringValue {
    return toString().split('.').last;
  }
}

/**
 * SettingsProvider - Persistent configuration management for UMI 海 - CAM
 * 
 * Features:
 * - SharedPreferences integration for persistent storage
 * - Video quality settings (LOW/MED/HIGH) with bitrate configuration
 * - Default camera layout preferences
 * - Smart Selfie crop toggle
 * - Watermark display toggle
 * - Real-time integration with CameraProvider and NativeCameraService
 */
class SettingsProvider extends ChangeNotifier {
  static const String _tag = 'SettingsProvider';

  // SharedPreferences keys
  static const String _keyVideoQuality = 'video_quality';
  static const String _keyDefaultLayout = 'default_layout';
  static const String _keySmartSelfieEnabled = 'is_smart_selfie_enabled';
  static const String _keyShowWatermark = 'show_watermark';
  static const String _keyFirstRun = 'is_first_run';

  // Settings state
  VideoQuality _videoQuality = VideoQuality.medium;
  DefaultLayout _defaultLayout = DefaultLayout.pip;
  bool _isSmartSelfieEnabled = true;
  bool _showWatermark = false;
  bool _isFirstRun = true;

  // Initialization state
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _errorMessage;

  SharedPreferences? _prefs;

  // ============================================================
  // PUBLIC GETTERS
  // ============================================================

  /// Current video quality setting
  VideoQuality get videoQuality => _videoQuality;

  /// Current default layout setting
  DefaultLayout get defaultLayout => _defaultLayout;

  /// Whether Smart Selfie crop is enabled
  bool get isSmartSelfieEnabled => _isSmartSelfieEnabled;

  /// Whether to show watermark on recordings
  bool get showWatermark => _showWatermark;

  /// Whether this is the first run of the app
  bool get isFirstRun => _isFirstRun;

  /// Whether settings have been initialized
  bool get isInitialized => _isInitialized;

  /// Whether settings are currently loading
  bool get isLoading => _isLoading;

  /// Current error message (if any)
  String? get errorMessage => _errorMessage;

  /// Get video quality configuration as Map for native integration
  Map<String, dynamic> get videoQualityConfig {
    return {
      'quality': _videoQuality.stringValue,
      'width': _videoQuality.width,
      'height': _videoQuality.height,
      'bitrate': _videoQuality.bitrate,
      'description': _videoQuality.description,
    };
  }

  /// Get all settings as a configuration map
  Map<String, dynamic> get allSettings {
    return {
      'videoQuality': _videoQuality.stringValue,
      'defaultLayout': _defaultLayout.stringValue,
      'isSmartSelfieEnabled': _isSmartSelfieEnabled,
      'showWatermark': _showWatermark,
      'isFirstRun': _isFirstRun,
    };
  }

  // ============================================================
  // INITIALIZATION
  // ============================================================

  /**
   * Initialize settings system and load persisted values
   */
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('$_tag: Settings already initialized');
      return;
    }

    _isLoading = true;
    _clearError();
    notifyListeners();

    try {
      debugPrint('$_tag: Initializing settings system...');

      // Get SharedPreferences instance
      _prefs = await SharedPreferences.getInstance();

      // Load all settings from persistent storage
      await _loadSettings();

      _isInitialized = true;
      debugPrint('$_tag: Settings initialization complete');

    } catch (e) {
      debugPrint('$_tag: Error during settings initialization: $e');
      _setError('Failed to initialize settings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /**
   * Load all settings from SharedPreferences
   */
  Future<void> _loadSettings() async {
    if (_prefs == null) return;

    try {
      // Load video quality
      final videoQualityStr = _prefs!.getString(_keyVideoQuality);
      if (videoQualityStr != null) {
        _videoQuality = VideoQualityExtension.fromString(videoQualityStr);
        debugPrint('$_tag: Loaded video quality: ${_videoQuality.displayName}');
      }

      // Load default layout
      final defaultLayoutStr = _prefs!.getString(_keyDefaultLayout);
      if (defaultLayoutStr != null) {
        _defaultLayout = DefaultLayoutExtension.fromString(defaultLayoutStr);
        debugPrint('$_tag: Loaded default layout: ${_defaultLayout.displayName}');
      }

      // Load Smart Selfie setting
      _isSmartSelfieEnabled = _prefs!.getBool(_keySmartSelfieEnabled) ?? true;
      debugPrint('$_tag: Loaded Smart Selfie enabled: $_isSmartSelfieEnabled');

      // Load watermark setting
      _showWatermark = _prefs!.getBool(_keyShowWatermark) ?? false;
      debugPrint('$_tag: Loaded watermark enabled: $_showWatermark');

      // Load first run flag
      _isFirstRun = _prefs!.getBool(_keyFirstRun) ?? true;
      debugPrint('$_tag: Loaded first run flag: $_isFirstRun');

      debugPrint('$_tag: All settings loaded successfully');

    } catch (e) {
      debugPrint('$_tag: Error loading settings: $e');
      throw Exception('Failed to load settings: $e');
    }
  }

  // ============================================================
  // SETTINGS MODIFICATION
  // ============================================================

  /**
   * Set video quality with persistence
   */
  Future<void> setVideoQuality(VideoQuality quality) async {
    if (_videoQuality == quality) return;

    try {
      _videoQuality = quality;
      
      if (_prefs != null) {
        await _prefs!.setString(_keyVideoQuality, quality.stringValue);
        debugPrint('$_tag: Video quality set to ${quality.displayName} (${quality.description})');
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('$_tag: Error setting video quality: $e');
      _setError('Failed to save video quality setting');
    }
  }

  /**
   * Set default layout with persistence
   */
  Future<void> setDefaultLayout(DefaultLayout layout) async {
    if (_defaultLayout == layout) return;

    try {
      _defaultLayout = layout;
      
      if (_prefs != null) {
        await _prefs!.setString(_keyDefaultLayout, layout.stringValue);
        debugPrint('$_tag: Default layout set to ${layout.displayName}');
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('$_tag: Error setting default layout: $e');
      _setError('Failed to save default layout setting');
    }
  }

  /**
   * Toggle Smart Selfie crop with persistence
   */
  Future<void> setSmartSelfieEnabled(bool enabled) async {
    if (_isSmartSelfieEnabled == enabled) return;

    try {
      _isSmartSelfieEnabled = enabled;
      
      if (_prefs != null) {
        await _prefs!.setBool(_keySmartSelfieEnabled, enabled);
        debugPrint('$_tag: Smart Selfie crop set to: $enabled');
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('$_tag: Error setting Smart Selfie: $e');
      _setError('Failed to save Smart Selfie setting');
    }
  }

  /**
   * Toggle watermark display with persistence
   */
  Future<void> setShowWatermark(bool show) async {
    if (_showWatermark == show) return;

    try {
      _showWatermark = show;
      
      if (_prefs != null) {
        await _prefs!.setBool(_keyShowWatermark, show);
        debugPrint('$_tag: Watermark display set to: $show');
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('$_tag: Error setting watermark: $e');
      _setError('Failed to save watermark setting');
    }
  }

  /**
   * Mark first run as completed
   */
  Future<void> markFirstRunComplete() async {
    try {
      _isFirstRun = false;
      
      if (_prefs != null) {
        await _prefs!.setBool(_keyFirstRun, false);
        debugPrint('$_tag: First run marked as complete');
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('$_tag: Error marking first run complete: $e');
    }
  }

  // ============================================================
  // SETTINGS RESET & UTILITIES
  // ============================================================

  /**
   * Reset all settings to default values
   */
  Future<void> resetAllSettings() async {
    try {
      debugPrint('$_tag: Resetting all settings to defaults...');

      _videoQuality = VideoQuality.medium;
      _defaultLayout = DefaultLayout.pip;
      _isSmartSelfieEnabled = true;
      _showWatermark = false;
      // Keep _isFirstRun as is to preserve onboarding state

      if (_prefs != null) {
        await _prefs!.setString(_keyVideoQuality, _videoQuality.stringValue);
        await _prefs!.setString(_keyDefaultLayout, _defaultLayout.stringValue);
        await _prefs!.setBool(_keySmartSelfieEnabled, _isSmartSelfieEnabled);
        await _prefs!.setBool(_keyShowWatermark, _showWatermark);
      }

      debugPrint('$_tag: All settings reset to defaults');
      notifyListeners();

    } catch (e) {
      debugPrint('$_tag: Error resetting settings: $e');
      _setError('Failed to reset settings');
    }
  }

  /**
   * Get comprehensive settings information for debugging
   */
  Map<String, dynamic> getSettingsDebugInfo() {
    return {
      'isInitialized': _isInitialized,
      'isLoading': _isLoading,
      'hasError': _errorMessage != null,
      'errorMessage': _errorMessage,
      'videoQuality': {
        'current': _videoQuality.displayName,
        'width': _videoQuality.width,
        'height': _videoQuality.height,
        'bitrate': _videoQuality.bitrate,
        'description': _videoQuality.description,
      },
      'defaultLayout': _defaultLayout.displayName,
      'isSmartSelfieEnabled': _isSmartSelfieEnabled,
      'showWatermark': _showWatermark,
      'isFirstRun': _isFirstRun,
      'prefsAvailable': _prefs != null,
    };
  }

  /**
   * Export settings as JSON string
   */
  String exportSettings() {
    return '''
{
  "videoQuality": "${_videoQuality.stringValue}",
  "defaultLayout": "${_defaultLayout.stringValue}",
  "isSmartSelfieEnabled": $_isSmartSelfieEnabled,
  "showWatermark": $_showWatermark,
  "exportedAt": "${DateTime.now().toIso8601String()}"
}''';
  }

  // ============================================================
  // ERROR HANDLING
  // ============================================================

  /**
   * Clear error state
   */
  void _clearError() {
    _errorMessage = null;
  }

  /**
   * Set error message
   */
  void _setError(String message) {
    _errorMessage = message;
    debugPrint('$_tag: Error - $message');
  }

  /**
   * Clear error and notify listeners
   */
  void clearError() {
    _clearError();
    notifyListeners();
  }

  @override
  void dispose() {
    debugPrint('$_tag: Disposing SettingsProvider...');
    super.dispose();
  }

  @override
  String toString() {
    return 'SettingsProvider(quality: ${_videoQuality.displayName}, layout: ${_defaultLayout.displayName}, smartSelfie: $_isSmartSelfieEnabled)';
  }
}
# UMI 海 - CAM
## Advanced Dual-Camera Recording Engine with Industrial Ocean Neo-Brutalism Design

[![Flutter](https://img.shields.io/badge/Flutter-3.10.4+-02569B?style=flat&logo=flutter)](https://flutter.dev/)
[![Android](https://img.shields.io/badge/Android-API%2021+-3DDC84?style=flat&logo=android)](https://developer.android.com/)
[![Kotlin](https://img.shields.io/badge/Kotlin-1.8+-7F52FF?style=flat&logo=kotlin)](https://kotlinlang.org/)

UMI 海 - CAM is a cutting-edge dual-camera recording application that enables simultaneous front and back camera capture with real-time video composition. Built with Flutter and powered by native Android Camera2 API, it features an Industrial Ocean Neo-Brutalist design system with interactive layouts, camera swapping, and professional-grade recording capabilities.

## 🌊 Key Features

### 📹 **Advanced Dual-Camera System**
- **Simultaneous Recording**: Capture both front and back cameras simultaneously
- **Real-Time Composition**: Live video composition with multiple layout modes
- **Interactive Layouts**: Draggable Picture-in-Picture (PiP) windows with resize functionality
- **Camera Swapping**: Seamless role reversal between primary and secondary cameras
- **Multi-Split Views**: Vertical and horizontal split-screen recording modes

### 🎨 **Industrial Ocean Neo-Brutalism Design**
- **Hard Borders & Shadows**: 3px solid black borders with 5px offset shadows
- **Bold Typography**: Archivo Black headers with Lexend body text
- **Ocean Color Palette**: Deep navy, ocean blue, mint green, and steel accents
- **Brutal UI Elements**: Sharp rectangles, industrial screws, and high contrast

### 🛡️ **Permission Guard System**
- **Immediate Permission Request**: Automatic permission handling on app launch
- **Neo-Brutalist Overlay**: Custom permission interface with clear status indicators
- **Comprehensive Access**: Camera, Microphone, and Media Library permissions
- **Settings Integration**: Direct app settings navigation for denied permissions

### 🔧 **Native Performance Optimization**
- **Android Camera2 API**: Native Kotlin implementation for maximum performance
- **YUV_420_888 Format**: Universal pixel format compatibility
- **Surface Producer API**: Android 15+ compatibility with modern texture handling
- **Enhanced Logging**: Comprehensive diagnostic system for debugging

## 🏗️ Architecture Overview

### Flutter Frontend
```
lib/
├── main.dart                          # App entry point with permission guard
├── providers/                         # State management
│   ├── camera_capability_provider.dart   # Hardware detection & permissions
│   ├── camera_provider.dart             # Camera operations & state
│   ├── gallery_provider.dart            # Media management
│   └── settings_provider.dart           # App configuration
├── screens/                           # Main UI screens
│   ├── home_screen.dart                 # Navigation hub
│   ├── recording_screen.dart            # Dual-camera interface
│   └── gallery_screen.dart              # Media library
├── widgets/                           # Reusable components
│   ├── permission_guard_overlay.dart     # Permission enforcement UI
│   ├── interactive_pip_view.dart         # Draggable PiP window
│   └── app_with_permission_guard.dart    # App wrapper
├── services/                          # Native integration
│   ├── native_camera_service.dart        # MethodChannel wrapper
│   └── hardware_bridge.dart             # Hardware detection
└── theme/                             # Design system
    ├── ocean_colors.dart                # Color palette
    └── ocean_theme.dart                 # Component themes
```

### Native Android Backend
```
android/app/src/main/kotlin/com/example/umi_cam/
├── MainActivity.kt                    # MethodChannel handler
├── DualCameraManager.kt              # Core camera operations
├── VideoComposer.kt                  # Real-time video composition
└── HardwareBridge.kt                 # Device capability detection
```

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK**: 3.10.4 or higher
- **Android Studio**: Latest version with Android SDK
- **Kotlin**: 1.8 or higher
- **Android Device**: API 21+ with dual cameras (recommended)

### Installation

1. **Clone the repository:**
```bash
git clone https://github.com/your-username/umi_cam.git
cd umi_cam
```

2. **Install Flutter dependencies:**
```bash
flutter pub get
```

3. **Configure Android permissions:**
The app automatically handles permissions, but ensure your Android manifest includes:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

4. **Build and run:**
```bash
flutter run --debug
```

## 🎮 Usage Guide

### First Launch
1. **Permission Request**: Grant Camera, Microphone, and Media Library access
2. **Hardware Detection**: Wait for dual-camera system initialization
3. **Home Screen**: Access recording, gallery, and settings

### Recording Interface
- **Layout Selection**: Choose PiP, Split Vertical, or Split Horizontal
- **Camera Swap**: Tap the swap button to reverse camera roles  
- **Interactive PiP**: Drag and resize the secondary camera window
- **Recording Controls**: Start/stop recording with visual feedback

### Layout Modes
- **Picture-in-Picture (PiP)**: Primary camera full-screen with draggable secondary window
- **Split Vertical**: Side-by-side camera feeds
- **Split Horizontal**: Top-bottom camera arrangement
- **Single Camera**: Front-only or back-only recording modes

## 🔧 Technical Implementation

### Permission System
```dart
// Automatic permission request on app launch
Future<bool> requestInitialPermissions() async {
  final permissions = [
    Permission.camera,
    Permission.microphone,
    Permission.photos,
  ];
  
  final results = await permissions.request();
  return results.values.every((status) => status == PermissionStatus.granted);
}
```

### Interactive PiP System
```dart
// Draggable PiP with coordinate tracking
class InteractivePiPView extends StatefulWidget {
  final Function(Rect pipRect)? onPositionChanged;
  
  // Real-time coordinate updates to native recording system
  void _notifyPositionChange() {
    final pipRect = Rect.fromLTWH(_position.dx, _position.dy, _size.width, _size.height);
    widget.onPositionChanged!(pipRect);
  }
}
```

### Native Camera Integration
```kotlin
// Dual camera with enhanced logging and error handling
class DualCameraManager {
    fun openCameras(callback: (Boolean, String?) -> Unit) {
        // Validate pixel format support
        validateCameraFormats(frontCameraId, "FRONT")
        validateCameraFormats(backCameraId, "BACK") 
        
        // Open both cameras with comprehensive error reporting
        cameraManager.openCamera(frontCameraId, frontCameraStateCallback, backgroundHandler)
        cameraManager.openCamera(backCameraId, backCameraStateCallback, backgroundHandler)
    }
}
```

## 🎨 Design System

### Color Palette
- **Deep Navy**: `#1A1B2E` - Dark backgrounds
- **Ocean Blue**: `#7AB2D3` - Primary accents and buttons
- **Steel Blue**: `#4A628A` - Headers and navigation
- **Mint Green**: `#DFF2EB` - Success states and backgrounds
- **Warning Orange**: `#F4A261` - Alert states
- **Error Red**: `#E76F51` - Error feedback

### Typography
- **Headers**: Archivo Black, 900 weight, high contrast
- **Body Text**: Lexend, 500-700 weight, optimized readability
- **System Text**: Monospace for technical information

### Component Design
- **Borders**: 3px solid black (`#000000`)
- **Shadows**: 5px offset, no blur for hard neo-brutalist effect
- **Buttons**: Sharp rectangles with heavy shadows
- **Cards**: High contrast with prominent borders

## 🛠️ Development Status

### ✅ Completed Features
- [x] Permission guard system with Neo-Brutalist UI
- [x] Dual-camera initialization and hardware detection
- [x] Interactive PiP windows with drag/resize functionality
- [x] Camera role swapping during active recording
- [x] Multi-layout recording (PiP, split views, single camera)
- [x] Native Android Camera2 API integration
- [x] YUV_420_888 pixel format compatibility
- [x] Android 15+ Surface Producer API support
- [x] Comprehensive error handling and logging
- [x] Industrial Ocean Neo-Brutalist design system
- [x] Video composition and encoding optimization
- [x] Gallery media management and playback
- [x] Advanced camera settings (resolution, FPS, bitrate)

### 🎯 Planned Features
- [ ] Social media sharing integration
- [ ] Cloud storage backup options
- [ ] AI-powered smart selfie cropping
- [ ] Real-time filters and effects
- [ ] Multi-device synchronization
- [ ] Professional video export options
- [ ] Accessibility improvements

## 🐛 Debugging & Troubleshooting

### Common Issues

**"System Not Ready" Error:**
- Fixed in latest version with automatic camera opening flow
- Enhanced logging shows detailed camera initialization progress

**Permission Denied:**
- Use the built-in permission overlay to grant required access
- Check device settings if permissions are permanently denied

**Camera Opening Failures:**
- Enhanced error logging identifies specific failure points
- Pixel format validation prevents compatibility issues

### Diagnostic Logs
The app provides comprehensive logging for debugging:
```
✅ FRONT CAMERA OPENED SUCCESSFULLY
🔧 Creating front camera capture session...
✅ FRONT CAPTURE SESSION CONFIGURED
🎉 BOTH CAMERAS ARE READY AND STREAMING
```

## 📱 Device Compatibility

### Recommended Devices
- **Nothing Phone (2)**: Full dual-camera support confirmed
- **Google Pixel**: Excellent Camera2 API implementation
- **Samsung Galaxy**: Wide compatibility across models
- **OnePlus**: Strong performance with concurrent cameras

### Minimum Requirements
- Android API 21+ (Android 5.0)
- Dual cameras (front + back)
- 4GB RAM minimum, 6GB+ recommended
- OpenGL ES 3.0+ support

## 🤝 Contributing

Contributions are welcome! Please read our contributing guidelines and code of conduct.

### Development Setup
1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

### Code Style
- Follow Dart/Flutter conventions
- Use meaningful variable names
- Add comprehensive documentation
- Include unit tests for new features
- Maintain the Industrial Ocean design consistency

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙋‍♂️ Support

- **Issues**: Report bugs and feature requests on GitHub Issues
- **Discussions**: Join community discussions for questions and ideas
- **Documentation**: Comprehensive guides in the `/docs` directory

## 🏆 Acknowledgments

- Flutter team for the excellent framework
- Android Camera2 API documentation and examples
- Industrial design inspiration from Dieter Rams
- Neo-Brutalism design movement
- Open source community contributions

---

**Built with ❤️ using Flutter, Kotlin, and Industrial Ocean Neo-Brutalism Design**

*UMI 海 - CAM: Where dual-camera technology meets bold design.*

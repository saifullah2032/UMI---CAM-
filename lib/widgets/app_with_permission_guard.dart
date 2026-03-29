import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/camera_capability_provider.dart';
import '../screens/home_screen.dart';
import '../widgets/permission_guard_overlay.dart';

/**
 * AppWithPermissionGuard - Main app wrapper with permission enforcement
 * 
 * Ensures all required permissions (Camera, Microphone, Media Library) are granted
 * before allowing access to the main app. Shows Neo-Brutalist overlay for denied permissions.
 */
class AppWithPermissionGuard extends StatefulWidget {
  const AppWithPermissionGuard({Key? key}) : super(key: key);

  @override
  State<AppWithPermissionGuard> createState() => _AppWithPermissionGuardState();
}

class _AppWithPermissionGuardState extends State<AppWithPermissionGuard> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Request permissions immediately after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestInitialPermissions();
    });
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When user returns from settings, check permissions again
    if (state == AppLifecycleState.resumed) {
      _requestInitialPermissions();
    }
  }
  
  /// Request initial permissions on app launch
  Future<void> _requestInitialPermissions() async {
    final capabilityProvider = context.read<CameraCapabilityProvider>();
    await capabilityProvider.requestInitialPermissions();
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer<CameraCapabilityProvider>(
      builder: (context, capabilityProvider, child) {
        // Show permission guard overlay if permissions not granted
        if (!capabilityProvider.permissionsGranted) {
          return PermissionGuardOverlay(
            permissionStatuses: capabilityProvider.permissionStatuses,
            isRequestInProgress: capabilityProvider.permissionCheckInProgress,
            onRetryPermissions: () async {
              await capabilityProvider.requestInitialPermissions();
            },
            onOpenSettings: () async {
              await capabilityProvider.openDeviceSettings();
            },
          );
        }
        
        // Show loading screen during hardware detection
        if (capabilityProvider.isLoading) {
          return const _LoadingScreen();
        }
        
        // Show main app when permissions granted and hardware detected
        return const HomeScreen();
      },
    );
  }
}

/**
 * Loading screen shown during hardware detection
 */
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDFF2EB), // OceanColors.mainBackground
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo/Title
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black,
                    offset: Offset(5, 5),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: const Text(
                'UMI 海 - CAM',
                style: TextStyle(
                  fontFamily: 'Archivo Black',
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF4A628A),
                  letterSpacing: 1.5,
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Loading indicator
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF7AB2D3),
                border: Border.all(color: Colors.black, width: 3),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                  SizedBox(width: 16),
                  Text(
                    'DETECTING HARDWARE...',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            const Text(
              'Initializing dual-camera system',
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
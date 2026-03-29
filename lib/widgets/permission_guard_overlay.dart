import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/ocean_colors.dart';
import '../theme/ocean_theme.dart';

/**
 * PermissionGuardOverlay - Neo-Brutalist permission blocking interface
 * 
 * Industrial Ocean design system overlay that prevents app access until
 * all required permissions (Camera, Microphone, Media Library) are granted.
 * Features hard borders, dramatic shadows, and clear permission status indicators.
 */
class PermissionGuardOverlay extends StatelessWidget {
  final Map<String, PermissionStatus> permissionStatuses;
  final VoidCallback onRetryPermissions;
  final VoidCallback onOpenSettings;
  final bool isRequestInProgress;

  const PermissionGuardOverlay({
    Key? key,
    required this.permissionStatuses,
    required this.onRetryPermissions,
    required this.onOpenSettings,
    this.isRequestInProgress = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OceanColors.deepNavy,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              OceanColors.deepNavy,
              OceanColors.mainBackground,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                _buildHeader(),
                
                const SizedBox(height: 32),
                
                // Permission Status Cards
                Expanded(
                  child: _buildPermissionStatusList(),
                ),
                
                const SizedBox(height: 24),
                
                // Action Buttons
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: OceanColors.surfaceWhite,
        border: Border.fromBorderSide(OceanTheme.brutalistBorder),
        boxShadow: [OceanTheme.brutalistShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App Title with Lock Icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: OceanColors.warningOrange,
                  border: Border.all(color: OceanColors.pureBorder, width: 2),
                ),
                child: const Icon(
                  Icons.lock,
                  color: OceanColors.surfaceWhite,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'UMI 海 - CAM',
                  style: TextStyle(
                    fontFamily: 'Archivo Black',
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: OceanColors.headerText,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Permission Required Message
          const Text(
            'PERMISSIONS REQUIRED',
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: OceanColors.warningOrange,
              letterSpacing: 1.0,
            ),
          ),
          
          const SizedBox(height: 8),
          
          const Text(
            'This app requires camera, microphone, and media access to function. Please grant all permissions to continue.',
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: OceanColors.primaryText,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionStatusList() {
    return Column(
      children: [
        _buildPermissionCard(
          'Camera',
          'Record dual-camera videos and capture photos',
          Icons.camera_alt,
          permissionStatuses['Camera'] ?? PermissionStatus.denied,
        ),
        
        const SizedBox(height: 16),
        
        _buildPermissionCard(
          'Microphone',
          'Record audio with your videos',
          Icons.mic,
          permissionStatuses['Microphone'] ?? PermissionStatus.denied,
        ),
        
        const SizedBox(height: 16),
        
        _buildPermissionCard(
          'Media Library',
          'Save and access your recorded videos',
          Icons.photo_library,
          permissionStatuses['Media Library'] ?? PermissionStatus.denied,
        ),
      ],
    );
  }

  Widget _buildPermissionCard(String title, String description, IconData icon, PermissionStatus status) {
    final bool isGranted = status == PermissionStatus.granted;
    final bool isPermanentlyDenied = status == PermissionStatus.permanentlyDenied;
    
    final Color statusColor = isGranted 
        ? OceanColors.systemPlaque 
        : isPermanentlyDenied 
            ? OceanColors.errorRed 
            : OceanColors.warningOrange;
            
    final IconData statusIcon = isGranted 
        ? Icons.check_circle 
        : isPermanentlyDenied 
            ? Icons.error 
            : Icons.warning;
            
    final String statusText = isGranted 
        ? 'GRANTED' 
        : isPermanentlyDenied 
            ? 'PERMANENTLY DENIED' 
            : 'DENIED';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isGranted ? OceanColors.surfaceWhite : OceanColors.mainBackground,
        border: Border.all(
          color: isGranted ? OceanColors.systemPlaque : statusColor, 
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.2),
            offset: const Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          // Permission Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor,
              border: Border.all(color: OceanColors.pureBorder, width: 2),
            ),
            child: Icon(
              icon,
              color: OceanColors.surfaceWhite,
              size: 24,
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Permission Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: OceanColors.headerText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: OceanColors.primaryText.withOpacity(0.7),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Status Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor,
              border: Border.all(color: OceanColors.pureBorder, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  statusIcon,
                  color: OceanColors.surfaceWhite,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  statusText,
                  style: const TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: OceanColors.surfaceWhite,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final bool hasPermanentlyDeniedPermissions = permissionStatuses.values
        .any((status) => status == PermissionStatus.permanentlyDenied);

    return Column(
      children: [
        // Retry Permissions Button
        if (!hasPermanentlyDeniedPermissions) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isRequestInProgress ? null : onRetryPermissions,
              style: ElevatedButton.styleFrom(
                backgroundColor: OceanColors.accentBlue,
                foregroundColor: OceanColors.surfaceWhite,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                  side: const BorderSide(
                    color: OceanColors.pureBorder,
                    width: 3,
                  ),
                ),
              ),
              child: isRequestInProgress 
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: OceanColors.surfaceWhite,
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'REQUESTING PERMISSIONS...',
                          style: TextStyle(
                            fontFamily: 'Lexend',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'GRANT PERMISSIONS',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
            ),
          ),
          
          const SizedBox(height: 12),
        ],
        
        // Open Settings Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onOpenSettings,
            style: OutlinedButton.styleFrom(
              backgroundColor: OceanColors.surfaceWhite,
              foregroundColor: OceanColors.primaryText,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
                side: const BorderSide(
                  color: OceanColors.pureBorder,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.settings,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  hasPermanentlyDeniedPermissions 
                      ? 'OPEN SETTINGS (REQUIRED)'
                      : 'OPEN SETTINGS',
                  style: const TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Help Text
        Text(
          hasPermanentlyDeniedPermissions
              ? 'Some permissions were permanently denied. Please enable them manually in Settings > Apps > UMI CAM > Permissions.'
              : 'Grant all permissions to access the dual-camera recording system.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: OceanColors.primaryText.withOpacity(0.7),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
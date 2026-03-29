import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/camera_capability_provider.dart';
import '../providers/camera_provider.dart';
import '../providers/gallery_provider.dart';
import '../theme/ocean_colors.dart';
import '../theme/ocean_theme.dart';
import '../widgets/ocean_background_painter.dart';
import 'recording_screen.dart';
import 'gallery_screen.dart';
import 'settings_screen.dart';

/// UMI 海 - CAM Home Screen
/// Industrial Ocean Neo-Brutalism Design with Reactive Hardware Detection
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: OceanColors.mainBackground,
      body: Stack(
        children: [
          // Background water ripples and sea illustrations
          CustomPaint(
            size: screenSize,
            painter: OceanBackgroundPainter(),
          ),
          
          // Main content
          SafeArea(
            child: Column(
              children: [
                // Header section
                _buildHeader(),
                
                // Reactive system status plaque
                _buildReactiveSystemStatusPlaque(context),
                
                // Main content area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: OceanTheme.spacingLg,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Reactive hero start button
                        _buildReactiveHeroStartButton(context),
                        
                        const SizedBox(height: OceanTheme.spacing2xl),
                        
                        // Feature cards grid
                        _buildFeatureCardsGrid(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      
      // Bottom navigation bar
      bottomNavigationBar: _buildNavigationBar(),
    );
  }
  
  /// Header with app title
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(OceanTheme.spacingLg),
      margin: const EdgeInsets.all(OceanTheme.spacingMd),
      decoration: OceanColorMethods.neoBrutalistBorder(
        backgroundColor: OceanColors.surfaceWhite,
      ),
      child: const Text(
        'UMI 海 - CAM',
        style: OceanTheme.headerStyle,
        textAlign: TextAlign.center,
      ),
    );
  }
  
  /// Reactive system status plaque that responds to hardware capabilities
  Widget _buildReactiveSystemStatusPlaque(BuildContext context) {
    return Consumer<CameraCapabilityProvider>(
      builder: (context, capabilityProvider, child) {
        // Determine plaque appearance based on hardware status
        final isSupported = capabilityProvider.isDualCameraSupported;
        final hasError = capabilityProvider.hasError;
        final isLoading = capabilityProvider.isLoading;
        
        // Get dynamic status text
        String statusText;
        if (isLoading) {
          statusText = 'SYSTEM CHECKING: HARDWARE...';
        } else {
          statusText = capabilityProvider.systemStatusText;
        }
        
        return Container(
          height: OceanTheme.systemPlaqueHeight,
          margin: const EdgeInsets.symmetric(horizontal: OceanTheme.spacingMd),
          decoration: OceanColorMethods.systemPlaqueDecoration(
            isDualCameraSupported: isSupported,
            hasError: hasError,
          ),
          child: Stack(
            children: [
              // Main content with loading indicator
              Center(
                child: isLoading 
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: OceanColors.primaryText,
                          ),
                        ),
                        const SizedBox(width: OceanTheme.spacingXs),
                        Text(
                          statusText,
                          style: OceanTheme.systemStatusStyle,
                        ),
                      ],
                    )
                  : GestureDetector(
                      onTap: () => _showHardwareDetails(context, capabilityProvider),
                      child: Text(
                        statusText,
                        style: OceanTheme.systemStatusStyle,
                      ),
                    ),
              ),
              
              // Industrial screw heads in corners (always visible for consistency)
              const Positioned(
                top: 8,
                left: 8,
                child: _ScrewHead(),
              ),
              const Positioned(
                top: 8,
                right: 8,
                child: _ScrewHead(),
              ),
              const Positioned(
                bottom: 8,
                left: 8,
                child: _ScrewHead(),
              ),
              const Positioned(
                bottom: 8,
                right: 8,
                child: _ScrewHead(),
              ),
            ],
          ),
        );
      },
    );
  }
  
  /// Reactive hero button that adapts to hardware capabilities
  Widget _buildReactiveHeroStartButton(BuildContext context) {
    return Consumer<CameraCapabilityProvider>(
      builder: (context, capabilityProvider, child) {
        final isSupported = capabilityProvider.isDualCameraSupported;
        final isLoading = capabilityProvider.isLoading;
        final hasError = capabilityProvider.hasError;
        
        // Determine button text and functionality
        String buttonText;
        VoidCallback? onTap;
        
        if (isLoading) {
          buttonText = 'DETECTING\nHARDWARE...';
          onTap = null; // Disabled while loading
        } else if (hasError) {
          buttonText = 'HARDWARE\nERROR';
          onTap = () => _showHardwareDetails(context, capabilityProvider);
        } else if (isSupported) {
          buttonText = 'START NEW\nSESSION';
          onTap = () => _startDualCameraSession(context);
        } else {
          buttonText = 'START SINGLE\nCAMERA';
          onTap = () => _startSingleCameraSession(context, capabilityProvider);
        }
        
        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: OceanTheme.heroButtonSize,
            height: OceanTheme.heroButtonSize,
            decoration: OceanColorMethods.heroButtonDecoration(
              backgroundColor: isLoading 
                ? OceanColors.warningOrange 
                : hasError 
                  ? OceanColors.errorRed
                  : OceanColors.accentBlue,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isLoading 
                    ? Icons.hourglass_empty
                    : hasError 
                      ? Icons.error_outline
                      : isSupported 
                        ? Icons.videocam
                        : Icons.camera_alt,
                  size: 48,
                  color: OceanColors.surfaceWhite,
                  weight: 700,
                ),
                const SizedBox(height: OceanTheme.spacingXs),
                Text(
                  buttonText,
                  style: OceanTheme.heroButtonStyle,
                  textAlign: TextAlign.center,
                ),
                // Show hardware hint for single camera mode
                if (!isLoading && !hasError && !isSupported) ...[
                  const SizedBox(height: 4),
                  Text(
                    capabilityProvider.unsupportedReason ?? 'Single cam mode',
                    style: OceanTheme.heroButtonStyle.copyWith(
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
  
  /// Show detailed hardware information dialog
  void _showHardwareDetails(BuildContext context, CameraCapabilityProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: OceanColors.surfaceWhite,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: OceanColors.pureBorder, width: 3),
        ),
        title: const Text(
          'HARDWARE CAPABILITIES',
          style: OceanTheme.subHeaderStyle,
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                provider.getCapabilitySummary(),
                style: const TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              if (provider.hasError)
                ElevatedButton(
                  onPressed: () {
                    provider.refreshCapabilities();
                    Navigator.of(context).pop();
                  },
                  child: const Text('RETRY DETECTION'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'CLOSE',
              style: TextStyle(
                color: OceanColors.deepSteelBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Start dual camera recording session
  void _startDualCameraSession(BuildContext context) {
    debugPrint('Starting dual camera session...');
    
    // Navigate to recording screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const RecordingScreen(),
      ),
    );
  }
  
  /// Start single camera recording session with warning
  void _startSingleCameraSession(BuildContext context, CameraCapabilityProvider provider) {
    debugPrint('Starting single camera session...');
    
    // Set camera layout to single camera mode and navigate
    final cameraProvider = context.read<CameraProvider>();
    cameraProvider.setLayout(CameraLayout.backOnly); // Default to back camera for single mode
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const RecordingScreen(),
      ),
    );
  }

  /// Open the media gallery
  void _openGallery(BuildContext context) {
    debugPrint('Opening media gallery...');
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const GalleryScreen(),
      ),
    );
  }

  /// Open the settings screen  
  void _openSettings(BuildContext context) {
    debugPrint('Opening settings screen...');
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }
  
  /// Feature cards in a responsive grid
  Widget _buildFeatureCardsGrid() {
    return Column(
      children: [
        // Top row: PiP Mode and Gallery
        Row(
          children: [
            // Card 1: PiP Mode
            Expanded(
              child: _buildFeatureCard(
                title: 'MODE: PiP 4:3',
                subtitle: 'Picture-in-Picture',
                icon: Icons.picture_in_picture_alt_outlined,
                onTap: () {
                  debugPrint('PiP mode selected');
                },
              ),
            ),
            
            const SizedBox(width: OceanTheme.spacingMd),
            
            // Card 2: Gallery
            Expanded(
              child: Consumer<GalleryProvider>(
                builder: (context, galleryProvider, child) {
                  return _buildFeatureCard(
                    title: 'MEDIA VAULT',
                    subtitle: '${galleryProvider.totalMediaCount} Files',
                    icon: Icons.photo_library,
                    onTap: () => _openGallery(context),
                  );
                }
              ),
            ),
          ],
        ),
        
        const SizedBox(height: OceanTheme.spacingMd),
        
        // Bottom row: Settings (full width)
        _buildFeatureCard(
          title: 'CONTROL CENTER',
          subtitle: 'Quality • Layout • System Config',
          icon: Icons.settings,
          onTap: () => _openSettings(context),
          isFullWidth: true,
        ),
      ],
    );
  }
  
  /// Individual feature card
  Widget _buildFeatureCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool isFullWidth = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: OceanTheme.featureCardHeight,
        width: isFullWidth ? double.infinity : null,
        decoration: OceanColorMethods.hardShadowBox(
          backgroundColor: OceanColors.systemPlaque,
        ),
        child: Padding(
          padding: const EdgeInsets.all(OceanTheme.spacingXs),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: OceanColors.deepSteelBlue,
                  weight: 600,
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: OceanTheme.cardTitleStyle.copyWith(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: OceanTheme.cardSubtitleStyle.copyWith(fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  /// Bottom navigation bar with Home, Gallery, and Settings
  Widget _buildNavigationBar() {
    return Container(
      height: OceanTheme.navigationBarHeight,
      decoration: const BoxDecoration(
        color: OceanColors.surfaceWhite,
        border: Border(
          top: BorderSide(
            color: OceanColors.pureBorder,
            width: 2.0,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const _NavigationItem(
            icon: Icons.home,
            label: 'Home',
            isActive: true,
          ),
          _NavigationItem(
            icon: Icons.photo_library,
            label: 'Gallery',
            isActive: false,
            onTap: () => _openGallery(context),
          ),
          _NavigationItem(
            icon: Icons.settings,
            label: 'Settings',
            isActive: false,
            onTap: () => _openSettings(context),
          ),
        ],
      ),
    );
  }
}

/// Industrial screw head widget
class _ScrewHead extends StatelessWidget {
  const _ScrewHead();
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: OceanTheme.screwHeadSize,
      height: OceanTheme.screwHeadSize,
      decoration: const BoxDecoration(
        color: OceanColors.deepSteelBlue,
        shape: BoxShape.circle,
        border: Border.fromBorderSide(
          BorderSide(
            color: OceanColors.pureBorder,
            width: 1.0,
          ),
        ),
      ),
      child: const Icon(
        Icons.add,
        size: 10,
        color: OceanColors.surfaceWhite,
      ),
    );
  }
}

/// Navigation bar item widget
class _NavigationItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;
  
  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.isActive,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    final color = isActive 
        ? OceanColors.activeNavigation 
        : OceanColors.inactiveNavigation;
    
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 28,
            color: color,
            weight: isActive ? 700 : 400,
          ),
          const SizedBox(height: OceanTheme.spacing2xs),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
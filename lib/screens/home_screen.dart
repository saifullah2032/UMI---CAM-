import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/camera_capability_provider.dart';
import '../providers/camera_provider.dart';
import '../providers/gallery_provider.dart';
import '../theme/ocean_colors.dart';
import '../theme/ocean_theme.dart';
import '../widgets/animated_ocean_background.dart';
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

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _headerController;
  late AnimationController _statusPlaqueController;
  late AnimationController _heroButtonController;
  late AnimationController _cardsController;
  late AnimationController _buttonSinkController;

  late Animation<Offset> _headerSlideAnimation;
  late Animation<Offset> _statusPlaqueSlideAnimation;
  late Animation<Offset> _heroButtonSlideAnimation;
  late Animation<Offset> _card1SlideAnimation;
  late Animation<Offset> _card2SlideAnimation;
  late Animation<Offset> _card3SlideAnimation;
  late Animation<double> _buttonShadowAnimation;

  @override
  void initState() {
    super.initState();

    // Header animation - slide from top
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _headerSlideAnimation =
        Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
          CurvedAnimation(parent: _headerController, curve: Curves.easeOut),
        );

    // Status plaque animation - slide from left
    _statusPlaqueController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _statusPlaqueSlideAnimation =
        Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _statusPlaqueController,
            curve: Curves.easeOut,
          ),
        );

    // Hero button animation - slide from bottom
    _heroButtonController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _heroButtonSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
          CurvedAnimation(parent: _heroButtonController, curve: Curves.easeOut),
        );

    // Feature cards animation - staggered slide
    _cardsController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Card 1 - slide from left
    _card1SlideAnimation =
        Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _cardsController,
            curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
          ),
        );

    // Card 2 - slide from right
    _card2SlideAnimation =
        Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _cardsController,
            curve: const Interval(0.35, 0.65, curve: Curves.easeOut),
          ),
        );

    // Card 3 (Settings) - slide from bottom
    _card3SlideAnimation =
        Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _cardsController,
            curve: const Interval(0.5, 0.8, curve: Curves.easeOut),
          ),
        );

    // Button sink/press animation - shadow and transform effect
    _buttonSinkController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _buttonShadowAnimation =
        Tween<double>(
          begin: 6.0, // Starting shadow offset
          end: 0.0, // Final shadow offset (no shadow)
        ).animate(
          CurvedAnimation(parent: _buttonSinkController, curve: Curves.easeOut),
        );

    // Start all animations
    _headerController.forward();
    _statusPlaqueController.forward();
    _heroButtonController.forward();
    _cardsController.forward();
  }

  @override
  void dispose() {
    _headerController.dispose();
    _statusPlaqueController.dispose();
    _heroButtonController.dispose();
    _cardsController.dispose();
    _buttonSinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OceanColors.mainBackground,
      body: Stack(
        children: [
          // Background water ripples and sea illustrations
          const AnimatedOceanBackground(),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Header section - slide from top
                SlideTransition(
                  position: _headerSlideAnimation,
                  child: _buildHeader(),
                ),

                // Reactive system status plaque - slide from left
                SlideTransition(
                  position: _statusPlaqueSlideAnimation,
                  child: _buildReactiveSystemStatusPlaque(context),
                ),

                // Main content area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: OceanTheme.spacingLg,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Reactive hero start button - slide from bottom
                        SlideTransition(
                          position: _heroButtonSlideAnimation,
                          child: _buildReactiveHeroStartButton(context),
                        ),

                        const SizedBox(height: OceanTheme.spacing2xl),

                        // Feature cards grid - staggered slide
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
                          Text(statusText, style: OceanTheme.systemStatusStyle),
                        ],
                      )
                    : GestureDetector(
                        onTap: () =>
                            _showHardwareDetails(context, capabilityProvider),
                        child: Text(
                          statusText,
                          style: OceanTheme.systemStatusStyle,
                        ),
                      ),
              ),

              // Industrial screw heads in corners (always visible for consistency)
              const Positioned(top: 8, left: 8, child: _ScrewHead()),
              const Positioned(top: 8, right: 8, child: _ScrewHead()),
              const Positioned(bottom: 8, left: 8, child: _ScrewHead()),
              const Positioned(bottom: 8, right: 8, child: _ScrewHead()),
            ],
          ),
        );
      },
    );
  }

  /// Reactive hero button that adapts to hardware capabilities
  Widget _buildReactiveHeroStartButton(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final buttonWidth = screenSize.width * 0.4; // 40% of screen width
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

        return StatefulBuilder(
          builder: (context, setState) {
            bool isPressed = false;

            return GestureDetector(
              onTap: onTap,
              onTapDown: (_) {
                if (onTap != null) {
                  setState(() => isPressed = true);
                  _buttonSinkController.forward();
                }
              },
              onTapUp: (_) {
                setState(() => isPressed = false);
                _buttonSinkController.reverse();
              },
              onTapCancel: () {
                setState(() => isPressed = false);
                _buttonSinkController.reverse();
              },
              child: AnimatedBuilder(
                animation: _buttonShadowAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _buttonShadowAnimation.value / 1.5),
                    child: Container(
                      width: buttonWidth,
                      height: buttonWidth, // Square button
                      decoration: BoxDecoration(
                        color: isLoading
                            ? OceanColors.warningOrange
                            : hasError
                            ? OceanColors.errorRed
                            : OceanColors.accentBlue,
                        border: const Border.fromBorderSide(
                          BorderSide(color: OceanColors.pureBorder, width: 3.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: OceanColors.deepSteelBlue.withValues(
                              alpha: 0.3,
                            ),
                            blurRadius: 0,
                            offset: Offset(0, _buttonShadowAnimation.value),
                          ),
                        ],
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
                              capabilityProvider.unsupportedReason ??
                                  'Single cam mode',
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
              ),
            );
          },
        );
      },
    );
  }

  /// Show detailed hardware information dialog
  void _showHardwareDetails(
    BuildContext context,
    CameraCapabilityProvider provider,
  ) {
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
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const RecordingScreen()));
  }

  /// Start single camera recording session with warning
  void _startSingleCameraSession(
    BuildContext context,
    CameraCapabilityProvider provider,
  ) {
    debugPrint('Starting single camera session...');

    // Set camera layout to single camera mode and navigate
    final cameraProvider = context.read<CameraProvider>();
    cameraProvider.setLayout(
      CameraLayout.backOnly,
    ); // Default to back camera for single mode

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const RecordingScreen()));
  }

  /// Open the media gallery
  void _openGallery(BuildContext context) {
    debugPrint('Opening media gallery...');

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const GalleryScreen()));
  }

  /// Open the settings screen
  void _openSettings(BuildContext context) {
    debugPrint('Opening settings screen...');

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const SettingsScreen()));
  }

  /// Feature cards in a responsive grid
  Widget _buildFeatureCardsGrid() {
    return Column(
      children: [
        // Top row: PiP Mode and Gallery
        Row(
          children: [
            // Card 1: PiP Mode - slide from left
            Expanded(
              child: SlideTransition(
                position: _card1SlideAnimation,
                child: _buildFeatureCard(
                  title: 'MODE: PiP 4:3',
                  subtitle: 'Picture-in-Picture',
                  icon: Icons.picture_in_picture_alt_outlined,
                  onTap: () {
                    debugPrint('PiP mode selected');
                  },
                ),
              ),
            ),

            const SizedBox(width: OceanTheme.spacingMd),

            // Card 2: Gallery - slide from right
            Expanded(
              child: SlideTransition(
                position: _card2SlideAnimation,
                child: Consumer<GalleryProvider>(
                  builder: (context, galleryProvider, child) {
                    return _buildFeatureCard(
                      title: 'VIDEO GALLERY',
                      subtitle: '${galleryProvider.totalMediaCount} Files',
                      icon: Icons.photo_library,
                      onTap: () => _openGallery(context),
                      isGallery: true,
                    );
                  },
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: OceanTheme.spacingMd),

        // Bottom row: Settings (full width) - slide from bottom
        SlideTransition(
          position: _card3SlideAnimation,
          child: _buildFeatureCard(
            title: 'CONTROL CENTER',
            subtitle: 'Quality • Layout • System Config',
            icon: Icons.settings,
            onTap: () => _openSettings(context),
            isFullWidth: true,
          ),
        ),
      ],
    );
  }

  /// Individual feature card with sinking button effect
  Widget _buildFeatureCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool isFullWidth = false,
    bool isGallery = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: StatefulBuilder(
        builder: (context, setState) {
          bool isPressed = false;

          return GestureDetector(
            onTapDown: (_) {
              setState(() => isPressed = true);
            },
            onTapUp: (_) {
              setState(() => isPressed = false);
              onTap();
            },
            onTapCancel: () {
              setState(() => isPressed = false);
            },
            child: Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: OceanTheme.featureCardHeight,
                  width: isFullWidth ? double.infinity : null,
                  transform: Matrix4.translationValues(0, isPressed ? 4 : 0, 0),
                  decoration: OceanColorMethods.hardShadowBox(
                    backgroundColor: OceanColors.systemPlaque,
                    shadowOffset: Offset(5, isPressed ? 0 : 5),
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
                            style: OceanTheme.cardTitleStyle.copyWith(
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: OceanTheme.cardSubtitleStyle.copyWith(
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Filmstrip decoration (only for gallery card)
                if (isGallery) ...[
                  // Left filmstrip
                  Positioned(
                    left: 4,
                    top: 0,
                    bottom: 0,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(
                        3,
                        (_) => Container(
                          width: 4,
                          height: 6,
                          decoration: BoxDecoration(
                            color: OceanColors.deepSteelBlue,
                            border: Border.all(
                              color: OceanColors.pureBorder,
                              width: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Right filmstrip
                  Positioned(
                    right: 4,
                    top: 0,
                    bottom: 0,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(
                        3,
                        (_) => Container(
                          width: 4,
                          height: 6,
                          decoration: BoxDecoration(
                            color: OceanColors.deepSteelBlue,
                            border: Border.all(
                              color: OceanColors.pureBorder,
                              width: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
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
          top: BorderSide(color: OceanColors.pureBorder, width: 2.0),
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
      decoration: BoxDecoration(
        color: OceanColors.deepSteelBlue,
        shape: BoxShape.circle,
        border: const Border.fromBorderSide(
          BorderSide(color: OceanColors.pureBorder, width: 1.0),
        ),
        boxShadow: [
          // Outer shadow for depth
          BoxShadow(
            color: OceanColors.deepSteelBlue.withValues(alpha: 0.4),
            offset: const Offset(2, 2),
            blurRadius: 2,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: OceanTheme.screwHeadSize - 4,
          height: OceanTheme.screwHeadSize - 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              // Inner shadow effect using inset-like approach
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                offset: const Offset(1, 1),
                blurRadius: 2,
                spreadRadius: 0,
              ),
            ],
          ),
          child: const Icon(
            Icons.add,
            size: 10,
            color: OceanColors.surfaceWhite,
          ),
        ),
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
          Icon(icon, size: 28, color: color, weight: isActive ? 700 : 400),
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

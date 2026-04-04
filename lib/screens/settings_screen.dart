import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../providers/camera_capability_provider.dart';
import '../theme/ocean_colors.dart';
import '../theme/ocean_theme.dart';

/**
 * SettingsScreen - Neo-Brutalist "Command Deck" for UMI 海 - CAM
 * 
 * Features the Industrial Ocean Control Center design:
 * - Pale Mint (#DFF2EB) background with Steel Blue (#4A628A) header
 * - Custom IndustrialSwitch widgets with mechanical toggle appearance
 * - Quality blocks that "sink" into the screen when selected
 * - Hardware diagnostic plaque with bolted-on metal plate styling
 * - About section with app version and branding
 */
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    _initializeSettings();
  }

  void _initializeSettings() async {
    final settingsProvider = context.read<SettingsProvider>();
    if (!settingsProvider.isInitialized) {
      await settingsProvider.initialize();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDFF2EB), // Pale Mint background
      appBar: _buildCommandDeckHeader(),
      body: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          if (settingsProvider.isLoading) {
            return _buildLoadingState();
          }

          if (settingsProvider.errorMessage != null) {
            return _buildErrorState(settingsProvider);
          }

          return _buildCommandDeckContent(settingsProvider);
        },
      ),
    );
  }

  /**
   * Command Deck header with Steel Blue background
   */
  PreferredSizeWidget _buildCommandDeckHeader() {
    return AppBar(
      backgroundColor: const Color(0xFF4A628A), // Steel Blue
      elevation: 0,
      title: const Text(
        'CONTROL CENTER',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w900,
          letterSpacing: 3,
          fontFamily: 'Archivo Black',
        ),
      ),
      centerTitle: true,
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }

  /**
   * Loading state for settings initialization
   */
  Widget _buildLoadingState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: OceanColors.steel,
          border: Border.fromBorderSide(OceanTheme.brutalistBorder),
          boxShadow: [OceanTheme.brutalistShadow],
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(OceanColors.mint),
              ),
            ),

            SizedBox(height: 24),

            Text(
              'INITIALIZING CONTROL CENTER...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /**
   * Error state display
   */
  Widget _buildErrorState(SettingsProvider settingsProvider) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: OceanColors.warning,
          border: Border.fromBorderSide(OceanTheme.brutalistBorder),
          boxShadow: [OceanTheme.brutalistShadow],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'CONTROL CENTER ERROR',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                fontFamily: 'Archivo Black',
              ),
            ),

            const SizedBox(height: 16),

            Text(
              settingsProvider.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
                letterSpacing: 1,
              ),
            ),

            const SizedBox(height: 24),

            GestureDetector(
              onTap: () => settingsProvider.initialize(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  color: OceanColors.steel,
                  border: Border.fromBorderSide(OceanTheme.brutalistBorder),
                  boxShadow: [OceanTheme.brutalistShadow],
                ),
                child: const Text(
                  'RETRY INITIALIZATION',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /**
   * Main command deck content
   */
  Widget _buildCommandDeckContent(SettingsProvider settingsProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Video Quality Control Panel
          _buildControlPanel(
            title: 'VIDEO QUALITY',
            icon: Icons.high_quality,
            child: _buildQualitySelector(settingsProvider),
          ),

          const SizedBox(height: 24),

          // Layout Configuration Panel
          _buildControlPanel(
            title: 'DEFAULT LAYOUT',
            icon: Icons.view_comfy,
            child: _buildLayoutSelector(settingsProvider),
          ),

          const SizedBox(height: 24),

          // Feature Switches Panel
          _buildControlPanel(
            title: 'FEATURE SWITCHES',
            icon: Icons.tune,
            child: _buildFeatureSwitches(settingsProvider),
          ),

          const SizedBox(height: 24),

          // Hardware Diagnostic Plaque
          _buildHardwareDiagnosticPlaque(),

          const SizedBox(height: 24),

          // About Section
          _buildAboutSection(),
        ],
      ),
    );
  }

  /**
   * Control panel container with Industrial styling
   */
  Widget _buildControlPanel({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border.fromBorderSide(OceanTheme.brutalistBorder),
        boxShadow: [OceanTheme.brutalistShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel header
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: OceanColors.steel,
                  border: Border.fromBorderSide(OceanTheme.brutalistBorder),
                ),
                child: Icon(icon, size: 18, color: Colors.white),
              ),

              const SizedBox(width: 12),

              Text(
                title,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  fontFamily: 'Archivo Black',
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Panel content
          child,
        ],
      ),
    );
  }

  /**
   * Video quality selector with sinking blocks
   */
  Widget _buildQualitySelector(SettingsProvider settingsProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select recording quality and bitrate configuration',
          style: TextStyle(
            color: Colors.black54,
            fontSize: 12,
            letterSpacing: 1,
          ),
        ),

        const SizedBox(height: 12),

        Row(
          children: VideoQuality.values
              .map(
                (quality) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildQualityBlock(quality, settingsProvider),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  /**
   * Individual quality block with sinking animation
   * Shadow goes from 6px to 0px with 4px downward transform on tap
   */
  Widget _buildQualityBlock(
    VideoQuality quality,
    SettingsProvider settingsProvider,
  ) {
    final isSelected = settingsProvider.videoQuality == quality;

    return GestureDetector(
      onTap: () => settingsProvider.setVideoQuality(quality),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        transform: Matrix4.translationValues(0, isSelected ? 4 : 0, 0),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF7AB2D3)
              : OceanColors.mint, // Ocean Blue when selected
          border: const Border.fromBorderSide(OceanTheme.brutalistBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black,
              offset: Offset(0, isSelected ? 0 : 6),
              blurRadius: 0,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              quality.displayName,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                fontFamily: 'Archivo Black',
              ),
            ),

            const SizedBox(height: 4),

            Text(
              quality.description,
              style: TextStyle(
                color: isSelected ? Colors.white70 : Colors.black54,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /**
   * Layout selector with toggle buttons
   */
  Widget _buildLayoutSelector(SettingsProvider settingsProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose default camera layout for new recording sessions',
          style: TextStyle(
            color: Colors.black54,
            fontSize: 12,
            letterSpacing: 1,
          ),
        ),

        const SizedBox(height: 12),

        Row(
          children: DefaultLayout.values
              .map(
                (layout) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildLayoutBlock(layout, settingsProvider),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  /**
   * Individual layout block
   */
  Widget _buildLayoutBlock(
    DefaultLayout layout,
    SettingsProvider settingsProvider,
  ) {
    final isSelected = settingsProvider.defaultLayout == layout;

    return GestureDetector(
      onTap: () => settingsProvider.setDefaultLayout(layout),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? OceanColors.ocean : OceanColors.steel,
          border: const Border.fromBorderSide(OceanTheme.brutalistBorder),
          boxShadow: const [OceanTheme.brutalistShadow],
        ),
        child: Column(
          children: [
            Icon(
              layout == DefaultLayout.pip
                  ? Icons.picture_in_picture_alt
                  : Icons.view_column,
              color: Colors.white,
              size: 24,
            ),

            const SizedBox(height: 8),

            Text(
              layout.shortName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /**
    * Feature switches with Industrial toggles
    */
  Widget _buildFeatureSwitches(SettingsProvider settingsProvider) {
    return Column(
      children: [
        // Smart Selfie Switch
        IndustrialSwitch(
          title: 'SMART SELFIE CROP',
          subtitle: 'AI-powered auto crop for front camera',
          value: settingsProvider.isSmartSelfieEnabled,
          onChanged: (value) => settingsProvider.setSmartSelfieEnabled(value),
        ),

        const SizedBox(height: 16),

        // Microphone Audio Switch
        IndustrialSwitch(
          title: 'MICROPHONE AUDIO',
          subtitle: 'Record audio from device microphone',
          value: settingsProvider.isMicrophoneAudioEnabled,
          onChanged: (value) =>
              settingsProvider.setMicrophoneAudioEnabled(value),
        ),

        const SizedBox(height: 16),

        // Watermark Switch
        IndustrialSwitch(
          title: 'WATERMARK',
          subtitle: 'Show UMI 海 - CAM branding on videos',
          value: settingsProvider.showWatermark,
          onChanged: (value) => settingsProvider.setShowWatermark(value),
        ),
      ],
    );
  }

  /**
   * Hardware diagnostic plaque with detailed camera and audio information
   */
  Widget _buildHardwareDiagnosticPlaque() {
    return Consumer<CameraCapabilityProvider>(
      builder: (context, capabilityProvider, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF2C3E50), // Dark steel background
            border: const Border.fromBorderSide(OceanTheme.brutalistBorder),
            boxShadow: const [OceanTheme.brutalistShadow],
          ),
          child: Stack(
            children: [
              // Main diagnostic content
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: OceanColors.warning,
                          border: Border.fromBorderSide(
                            OceanTheme.brutalistBorder,
                          ),
                        ),
                        child: const Icon(
                          Icons.memory,
                          size: 18,
                          color: Colors.black,
                        ),
                      ),

                      const SizedBox(width: 12),

                      const Text(
                        'HARDWARE DIAGNOSTICS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          fontFamily: 'Archivo Black',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Hardware info rows
                  _buildDiagnosticRow(
                    'DEVICE',
                    capabilityProvider.capabilities.deviceModel ??
                        'Unknown Model',
                  ),
                  const SizedBox(height: 10),

                  _buildDiagnosticRow(
                    'FRONT CAMERA',
                    capabilityProvider.capabilities.hasFrontCamera
                        ? 'ACTIVE'
                        : 'N/A',
                  ),
                  const SizedBox(height: 10),

                  _buildDiagnosticRow(
                    'BACK CAMERA',
                    capabilityProvider.capabilities.hasBackCamera
                        ? 'ACTIVE'
                        : 'N/A',
                  ),
                  const SizedBox(height: 10),

                  _buildDiagnosticRow(
                    'DUAL CAMERA',
                    capabilityProvider.capabilities.isDualCameraSupported
                        ? 'SUPPORTED'
                        : 'NOT SUPPORTED',
                  ),
                  const SizedBox(height: 10),

                  _buildDiagnosticRow('AUDIO INPUT', 'MICROPHONE READY'),
                ],
              ),

              // Industrial bolts in corners
              _buildIndustrialBolts(),
            ],
          ),
        );
      },
    );
  }

  /**
   * Diagnostic information row
   */
  Widget _buildDiagnosticRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              letterSpacing: 1,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const Text(': ', style: TextStyle(color: Colors.white70)),

        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              letterSpacing: 0.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  /**
   * Industrial bolts for the diagnostic plaque
   */
  Widget _buildIndustrialBolts() {
    return Stack(
      children: [
        // Top-left bolt
        const Positioned(top: 8, left: 8, child: _IndustrialBolt()),

        // Top-right bolt
        const Positioned(top: 8, right: 8, child: _IndustrialBolt()),

        // Bottom-left bolt
        const Positioned(bottom: 8, left: 8, child: _IndustrialBolt()),

        // Bottom-right bolt
        const Positioned(bottom: 8, right: 8, child: _IndustrialBolt()),
      ],
    );
  }

  /**
   * About section with app version
   */
  Widget _buildAboutSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: OceanColors.steel,
        border: Border.fromBorderSide(OceanTheme.brutalistBorder),
        boxShadow: [OceanTheme.brutalistShadow],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: OceanColors.mint,
              border: Border.fromBorderSide(OceanTheme.brutalistBorder),
            ),
            child: const Text(
              'UMI 海 - CAM',
              style: TextStyle(
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                fontFamily: 'Archivo Black',
              ),
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'v1.0.0',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Industrial Ocean Neo-Brutalism Design\nDual-Camera Recording Engine',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/**
 * Custom Industrial Switch widget with mechanical toggle appearance
 */
class IndustrialSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const IndustrialSwitch({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          // Switch information
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    fontFamily: 'Archivo Black',
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // Industrial toggle switch
          Container(
            width: 80,
            height: 40,
            decoration: BoxDecoration(
              color: value ? OceanColors.ocean : OceanColors.steel,
              border: const Border.fromBorderSide(OceanTheme.brutalistBorder),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black,
                  offset: Offset(4, 4),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Switch track
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    mainAxisAlignment: value
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    children: [
                      // Switch handle
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border.fromBorderSide(
                            BorderSide(color: Colors.black, width: 2),
                          ),
                        ),
                        child: Icon(
                          value ? Icons.check : Icons.close,
                          size: 16,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/**
 * Industrial bolt widget for hardware diagnostic plaque
 */
class _IndustrialBolt extends StatelessWidget {
  const _IndustrialBolt();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: const BoxDecoration(
        color: Colors.black54,
        shape: BoxShape.circle,
        border: Border.fromBorderSide(
          BorderSide(color: Colors.black, width: 1),
        ),
      ),
      child: CustomPaint(painter: BoltPainter()),
    );
  }
}

/**
 * Custom painter for bolt cross detail
 */
class BoltPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final crossSize = size.width * 0.4;

    // Horizontal line
    canvas.drawLine(
      Offset(center.dx - crossSize / 2, center.dy),
      Offset(center.dx + crossSize / 2, center.dy),
      paint,
    );

    // Vertical line
    canvas.drawLine(
      Offset(center.dx, center.dy - crossSize / 2),
      Offset(center.dx, center.dy + crossSize / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

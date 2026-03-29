import 'package:flutter/material.dart';
import 'ocean_colors.dart';

/// Industrial Ocean Neo-Brutalism Theme System
/// Typography and component styling for UMI 海 - CAM
class OceanTheme {
  
  /// Primary text styles using heavy/bold typography
  static const TextStyle headerStyle = TextStyle(
    fontFamily: 'Archivo Black', // Fallback to system bold if not available
    fontSize: 28,
    fontWeight: FontWeight.w900,
    color: OceanColors.headerText,
    letterSpacing: 1.2,
  );
  
  static const TextStyle subHeaderStyle = TextStyle(
    fontFamily: 'Lexend',
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: OceanColors.primaryText,
    letterSpacing: 0.8,
  );
  
  static const TextStyle systemStatusStyle = TextStyle(
    fontFamily: 'Lexend',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: OceanColors.primaryText,
    letterSpacing: 2.0, // Wide letter spacing for industrial look
  );
  
  static const TextStyle heroButtonStyle = TextStyle(
    fontFamily: 'Archivo Black',
    fontSize: 16,
    fontWeight: FontWeight.w900,
    color: OceanColors.surfaceWhite,
    letterSpacing: 1.5,
  );
  
  static const TextStyle cardTitleStyle = TextStyle(
    fontFamily: 'Lexend',
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: OceanColors.primaryText,
    letterSpacing: 0.5,
  );
  
  static const TextStyle cardSubtitleStyle = TextStyle(
    fontFamily: 'Lexend',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: OceanColors.deepSteelBlue,
    letterSpacing: 0.3,
  );
  
  /// Neo-Brutalist component dimensions
  static const double standardBorderWidth = 3.0;
  static const double heroBorderWidth = 4.0;
  static const double cardBorderRadius = 0.0; // Sharp corners for neo-brutalism
  static const Offset standardShadowOffset = Offset(5, 5);
  static const Offset heroShadowOffset = Offset(7, 7);
  
  /// Standard spacing system
  static const double spacing2xs = 4.0;
  static const double spacingXs = 8.0;
  static const double spacingSm = 12.0;
  static const double spacingM = 16.0;   // Medium spacing alias
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacing2xl = 48.0;
  static const double spacing3xl = 64.0;
  
  /// Neo-Brutalist styling constants
  static const BorderSide brutalistBorder = BorderSide(
    color: OceanColors.pureBorder,
    width: 3.0,
  );
  
  static const BoxShadow brutalistShadow = BoxShadow(
    color: OceanColors.shadowColor,
    offset: Offset(5, 5),
    blurRadius: 0,
    spreadRadius: 0,
  );
  
  /// Component sizing
  static const double heroButtonSize = 160.0;
  static const double featureCardHeight = 100.0; // Reduced from 120.0
  static const double systemPlaqueHeight = 56.0;
  static const double navigationBarHeight = 80.0;
  static const double screwHeadSize = 16.0;
  
  /// Private constructor
  OceanTheme._();
}

/// Extension for creating themed widgets
extension OceanThemeWidgets on OceanTheme {
  
  /// Screw head decoration for industrial details
  static Widget screwHead() {
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
        Icons.add, // Cross-head screw icon
        size: 10,
        color: OceanColors.surfaceWhite,
      ),
    );
  }
  
  /// Industrial divider line
  static Widget industrialDivider({
    double height = 2.0,
    Color color = OceanColors.pureBorder,
  }) {
    return Container(
      height: height,
      color: color,
    );
  }
}
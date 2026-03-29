import 'package:flutter/material.dart';

/// Industrial Ocean Neo-Brutalism Color System
/// Strict palette for UMI 海 - CAM
class OceanColors {
  // Core Palette
  static const Color mainBackground = Color(0xFFDFF2EB); // Very pale mint
  static const Color mint = Color(0xFFDFF2EB);           // Alias for mint
  static const Color accentBlue = Color(0xFF7AB2D3);      // Ocean Blue
  static const Color ocean = Color(0xFF7AB2D3);           // Alias for ocean
  static const Color deepSteelBlue = Color(0xFF4A628A);   // Headers/Titles
  static const Color steel = Color(0xFF4A628A);           // Alias for steel
  static const Color systemPlaque = Color(0xFFB9E5E8);    // System status bar (success)
  static const Color pureBorder = Color(0xFF000000);      // Pure Black borders
  
  // System Status Colors
  static const Color warningOrange = Color(0xFFF4A261);   // Warning/Single camera mode
  static const Color warning = Color(0xFFF4A261);         // Alias for warning
  static const Color errorRed = Color(0xFFE76F51);        // Error state
  static const Color error = Color(0xFFE76F51);           // Alias for error
  
  // Background Colors
  static const Color deepNavy = Color(0xFF1A1B2E);        // Dark background
  
  // Neo-Brutalist Shadow System
  static const Color shadowColor = Color(0xFF000000);     // Hard black shadows
  
  // Text Colors
  static const Color primaryText = Color(0xFF000000);     // High contrast black
  static const Color headerText = deepSteelBlue;          // Deep steel blue headers
  
  // Interactive States
  static const Color activeNavigation = accentBlue;       // Active nav items
  static const Color inactiveNavigation = Color(0xFF6B7280); // Inactive nav items
  
  // Illustration Colors (Low Opacity)
  static const Color illustrationBlue = Color(0x334A628A); // Deep blue at 20% opacity
  
  // White/Light Colors
  static const Color surfaceWhite = Color(0xFFFFFFFF);    // Navigation bar background
  
  // Private constructor to prevent instantiation
  OceanColors._();
}

/// Extension for commonly used color combinations
extension OceanColorMethods on OceanColors {
  /// Standard Neo-Brutalist border decoration
  static BoxDecoration neoBrutalistBorder({
    Color backgroundColor = OceanColors.surfaceWhite,
    double borderWidth = 3.0,
  }) {
    return BoxDecoration(
      color: backgroundColor,
      border: Border.all(
        color: OceanColors.pureBorder,
        width: borderWidth,
      ),
    );
  }
  
  /// Hard shadow box decoration (no blur)
  static BoxDecoration hardShadowBox({
    Color backgroundColor = OceanColors.surfaceWhite,
    double borderWidth = 3.0,
    Offset shadowOffset = const Offset(5, 5),
  }) {
    return BoxDecoration(
      color: backgroundColor,
      border: Border.all(
        color: OceanColors.pureBorder,
        width: borderWidth,
      ),
      boxShadow: [
        BoxShadow(
          color: OceanColors.shadowColor,
          offset: shadowOffset,
          blurRadius: 0, // No blur for hard shadow
          spreadRadius: 0,
        ),
      ],
    );
  }
  
  /// Hero button decoration with heavy shadow
  static BoxDecoration heroButtonDecoration({
    Color backgroundColor = OceanColors.accentBlue,
  }) {
    return BoxDecoration(
      color: backgroundColor,
      border: Border.all(
        color: OceanColors.pureBorder,
        width: 4.0,
      ),
      shape: BoxShape.circle,
      boxShadow: const [
        BoxShadow(
          color: OceanColors.shadowColor,
          offset: Offset(7, 7), // Heavy shadow for hero button
          blurRadius: 0,
          spreadRadius: 0,
        ),
      ],
    );
  }
  
  /// Dynamic system plaque decoration based on hardware status
  static BoxDecoration systemPlaqueDecoration({
    required bool isDualCameraSupported,
    bool hasError = false,
  }) {
    Color backgroundColor;
    
    if (hasError) {
      backgroundColor = OceanColors.errorRed;
    } else if (isDualCameraSupported) {
      backgroundColor = OceanColors.systemPlaque; // Success mint
    } else {
      backgroundColor = OceanColors.warningOrange; // Single camera warning
    }
    
    return BoxDecoration(
      color: backgroundColor,
      border: Border.all(
        color: OceanColors.pureBorder,
        width: 3.0,
      ),
    );
  }
}
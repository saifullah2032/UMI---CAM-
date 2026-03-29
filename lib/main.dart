import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'widgets/app_with_permission_guard.dart';
import 'theme/ocean_colors.dart';
import 'providers/camera_capability_provider.dart';
import 'providers/camera_provider.dart';
import 'providers/gallery_provider.dart';
import 'providers/settings_provider.dart';

void main() {
  // Set system UI overlay style for Industrial Ocean theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: OceanColors.surfaceWhite,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  runApp(const UmiCamApp());
}

class UmiCamApp extends StatelessWidget {
  const UmiCamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => CameraCapabilityProvider()),
        ChangeNotifierProvider(create: (context) => CameraProvider()),
        ChangeNotifierProvider(create: (context) => GalleryProvider()),
        ChangeNotifierProvider(create: (context) => SettingsProvider()),
      ],
      child: MaterialApp(
        title: 'UMI 海 - CAM',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          // Industrial Ocean Neo-Brutalism theme
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: OceanColors.mainBackground,
          fontFamily: 'Lexend', // Primary font family
          
          // AppBar theme (if needed for other screens)
          appBarTheme: const AppBarTheme(
            backgroundColor: OceanColors.surfaceWhite,
            foregroundColor: OceanColors.primaryText,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              fontFamily: 'Archivo Black',
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: OceanColors.headerText,
              letterSpacing: 1.0,
            ),
          ),
          
          // Button themes
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: OceanColors.accentBlue,
              foregroundColor: OceanColors.surfaceWhite,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
                side: const BorderSide(
                  color: OceanColors.pureBorder,
                  width: 3.0,
                ),
              ),
              textStyle: const TextStyle(
                fontFamily: 'Lexend',
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
          
          // Material 3 design system
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: OceanColors.accentBlue,
            brightness: Brightness.light,
            surface: OceanColors.surfaceWhite,
          ),
        ),
        home: const AppWithPermissionGuard(),
      ),
    );
  }
}
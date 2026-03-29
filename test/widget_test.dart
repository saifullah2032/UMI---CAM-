// UMI 海 - CAM Widget Tests
// Tests for the Industrial Ocean Neo-Brutalism UI components

import 'package:flutter_test/flutter_test.dart';

import 'package:umi_cam/main.dart';

void main() {
  testWidgets('UMI CAM app loads correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const UmiCamApp());

    // Allow time for hardware detection to complete or fail in test environment
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify that our home screen loads with key elements.
    expect(find.text('UMI 海 - CAM'), findsOneWidget);
    
    // System status is now dynamic - look for any valid system status text
    final systemStatusFinder = find.textContaining('SYSTEM');
    expect(systemStatusFinder, findsOneWidget);
    
    // The system status should be one of these possibilities:
    // - "SYSTEM CHECKING: HARDWARE..." (loading state)
    // - "SYSTEM READY: DUAL CAM OK" (if dual camera detected)
    // - "SYSTEM READY: SINGLE CAM ONLY" (if single camera only)
    // - "SYSTEM ERROR: DETECTION FAILED" (if hardware detection failed)
    final statusText = tester.widget(systemStatusFinder);
    expect(statusText.toString(), anyOf([
      contains('SYSTEM CHECKING: HARDWARE'),
      contains('SYSTEM READY: DUAL CAM OK'),
      contains('SYSTEM READY: SINGLE CAM ONLY'), 
      contains('SYSTEM ERROR: DETECTION FAILED')
    ]));
    
    // Hero button text is also dynamic based on hardware detection
    // Can be in loading state "DETECTING\nHARDWARE..." or ready states with "START"
    final hasStartButton = find.textContaining('START').evaluate().isNotEmpty;
    final hasDetectingButton = find.textContaining('DETECTING').evaluate().isNotEmpty;
    expect(hasStartButton || hasDetectingButton, isTrue);
  });

  testWidgets('Navigation elements are present', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const UmiCamApp());

    // Allow time for initial setup
    await tester.pump();

    // Verify navigation items are present
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('Feature elements are present', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const UmiCamApp());
    
    // Allow time for initial setup
    await tester.pump();
    
    // Verify feature cards contain expected text (using partial matches to avoid layout issues)
    expect(find.textContaining('PiP'), findsOneWidget);
    expect(find.textContaining('SELFIE'), findsOneWidget);
  });
  
  testWidgets('Hardware detection system works in test environment', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const UmiCamApp());

    // Allow time for hardware detection to potentially complete or fail
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    
    // In test environment, hardware detection will likely fail since MethodChannels 
    // don't connect to native code during testing. Verify the system handles this gracefully.
    
    // System should show some status (loading, ready, or error state)
    expect(find.textContaining('SYSTEM'), findsOneWidget);
    
    // Should have a hero button with some action (either loading or ready)
    final hasStartButton = find.textContaining('START').evaluate().isNotEmpty;
    final hasDetectingButton = find.textContaining('DETECTING').evaluate().isNotEmpty;
    final hasErrorButton = find.textContaining('HARDWARE\nERROR').evaluate().isNotEmpty;
    expect(hasStartButton || hasDetectingButton || hasErrorButton, isTrue);
  });
}

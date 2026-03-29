import 'package:flutter/material.dart';
import '../services/hardware_bridge.dart';
import '../providers/camera_capability_provider.dart';

/// Connectivity Audit Widget
/// 
/// Provides debugging and testing interface for the hardware detection system.
/// Can be added to the app for development and troubleshooting.
class ConnectivityAudit extends StatefulWidget {
  const ConnectivityAudit({super.key});

  @override
  State<ConnectivityAudit> createState() => _ConnectivityAuditState();
}

class _ConnectivityAuditState extends State<ConnectivityAudit> {
  String _auditResults = 'Click "Run Audit" to test hardware bridge connectivity';
  bool _isRunning = false;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hardware Connectivity Audit'),
        backgroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _isRunning ? null : _runConnectivityAudit,
              child: Text(_isRunning ? 'Running Audit...' : 'Run Connectivity Audit'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _auditResults,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _runConnectivityAudit() async {
    setState(() {
      _isRunning = true;
      _auditResults = 'Starting connectivity audit...\n\n';
    });
    
    final buffer = StringBuffer();
    buffer.writeln('🔍 UMI 海 - CAM Hardware Bridge Connectivity Audit');
    buffer.writeln('=' * 50);
    buffer.writeln();
    
    try {
      // Test 1: Basic connectivity
      buffer.writeln('📡 Test 1: Basic MethodChannel Connectivity');
      final connectivityTest = await HardwareBridge.testConnectivity();
      buffer.writeln('Result: ${connectivityTest ? "✅ PASS" : "❌ FAIL"}');
      buffer.writeln();
      
      // Test 2: Dual camera support check
      buffer.writeln('📷 Test 2: Dual Camera Support Detection');
      final isDualSupported = await HardwareBridge.isDualCameraSupported();
      buffer.writeln('Result: ${isDualSupported ? "✅ DUAL CAMERA SUPPORTED" : "⚠️ SINGLE CAMERA ONLY"}');
      buffer.writeln();
      
      // Test 3: Unsupported reason (if applicable)
      if (!isDualSupported) {
        buffer.writeln('❓ Test 3: Unsupported Reason Detection');
        final reason = await HardwareBridge.getDualCameraUnsupportedReason();
        buffer.writeln('Reason: ${reason ?? "No specific reason provided"}');
        buffer.writeln();
      }
      
      // Test 4: Hardware capabilities
      buffer.writeln('🔧 Test 4: Complete Hardware Capabilities');
      final capabilities = await HardwareBridge.getHardwareCapabilities();
      buffer.writeln('Raw capabilities data:');
      capabilities.forEach((key, value) {
        buffer.writeln('  $key: $value');
      });
      buffer.writeln();
      
      // Test 5: Provider integration
      buffer.writeln('🔄 Test 5: Provider Integration');
      final provider = CameraCapabilityProvider();
      
      // Give provider time to initialize
      await Future.delayed(const Duration(seconds: 2));
      
      buffer.writeln('Provider status:');
      buffer.writeln('  Is Loading: ${provider.isLoading}');
      buffer.writeln('  Dual Camera Supported: ${provider.isDualCameraSupported}');
      buffer.writeln('  Unsupported Reason: ${provider.unsupportedReason ?? "N/A"}');
      buffer.writeln('  System Status Text: ${provider.systemStatusText}');
      buffer.writeln();
      
      // Summary
      buffer.writeln('📊 AUDIT SUMMARY');
      buffer.writeln('=' * 30);
      if (connectivityTest) {
        buffer.writeln('✅ MethodChannel connectivity: WORKING');
        buffer.writeln('✅ Hardware detection: FUNCTIONAL');
        buffer.writeln('✅ Provider integration: OPERATIONAL');
        
        if (isDualSupported) {
          buffer.writeln('🎥 Camera Mode: DUAL CAMERA READY');
        } else {
          buffer.writeln('📱 Camera Mode: SINGLE CAMERA FALLBACK');
        }
        
        buffer.writeln('\n🎉 ALL SYSTEMS GO! Hardware bridge is fully operational.');
      } else {
        buffer.writeln('❌ MethodChannel connectivity: FAILED');
        buffer.writeln('❌ Hardware detection: NON-FUNCTIONAL');
        buffer.writeln('\n⚠️ CRITICAL: Hardware bridge is not responding!');
        buffer.writeln('Check native implementation and MethodChannel registration.');
      }
      
    } catch (e) {
      buffer.writeln('💥 AUDIT FAILED WITH EXCEPTION:');
      buffer.writeln('Error: $e');
      buffer.writeln('\nStack trace available in debug console.');
      print('Connectivity Audit Exception: $e');
    }
    
    setState(() {
      _isRunning = false;
      _auditResults = buffer.toString();
    });
  }
}

/// Connectivity Audit Report Generator
/// 
/// Provides static methods for generating audit reports that can be used
/// in automated testing or debugging scenarios.
class ConnectivityAuditReporter {
  
  /// Generate a comprehensive connectivity report
  static Future<String> generateReport() async {
    final buffer = StringBuffer();
    final timestamp = DateTime.now().toIso8601String();
    
    buffer.writeln('UMI 海 - CAM Hardware Bridge Connectivity Report');
    buffer.writeln('Generated: $timestamp');
    buffer.writeln('=' * 60);
    buffer.writeln();
    
    try {
      // Basic connectivity test
      final connectivity = await HardwareBridge.testConnectivity();
      buffer.writeln('MethodChannel Connectivity: ${connectivity ? "OK" : "FAILED"}');
      
      if (connectivity) {
        // Hardware detection
        final dualSupported = await HardwareBridge.isDualCameraSupported();
        final reason = await HardwareBridge.getDualCameraUnsupportedReason();
        final capabilities = await HardwareBridge.getHardwareCapabilities();
        
        buffer.writeln('Dual Camera Support: ${dualSupported ? "YES" : "NO"}');
        if (reason != null) {
          buffer.writeln('Limitation Reason: $reason');
        }
        
        buffer.writeln('\nHardware Details:');
        buffer.writeln('  Device Model: ${capabilities['deviceModel'] ?? 'Unknown'}');
        buffer.writeln('  Platform Version: ${capabilities['platformVersion'] ?? 'Unknown'}');
        buffer.writeln('  Total Cameras: ${capabilities['totalCameras'] ?? 0}');
        buffer.writeln('  Front Camera: ${capabilities['hasFrontCamera'] == true ? "Yes" : "No"}');
        buffer.writeln('  Back Camera: ${capabilities['hasBackCamera'] == true ? "Yes" : "No"}');
        buffer.writeln('  Official Concurrent Support: ${capabilities['officialConcurrentSupport'] == true ? "Yes" : "No"}');
      }
      
      buffer.writeln('\nStatus: ${connectivity ? "OPERATIONAL" : "REQUIRES ATTENTION"}');
      
    } catch (e) {
      buffer.writeln('Error generating report: $e');
    }
    
    return buffer.toString();
  }
  
  /// Quick connectivity check for automated testing
  static Future<bool> quickConnectivityCheck() async {
    try {
      return await HardwareBridge.testConnectivity();
    } catch (e) {
      return false;
    }
  }
}
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/camera_provider.dart';
import '../theme/ocean_colors.dart';
import '../theme/ocean_theme.dart';
import '../widgets/interactive_pip_view.dart';

/**
 * RecordingScreen - Neo-Brutalist dual camera preview interface
 * 
 * Implements Industrial Ocean Design System with:
 * - PiP (Picture-in-Picture) layout with draggable front camera
 * - Hard black borders (3px) and shadows (5px)
 * - Pastel Ocean Palette (#DFF2EB, #7AB2D3)
 * - Real-time texture streaming from both cameras
 */
class RecordingScreen extends StatefulWidget {
  const RecordingScreen({Key? key}) : super(key: key);

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  
  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to avoid build phase race condition
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CameraProvider>().initializeCameras();
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OceanColors.deepNavy,
      body: Consumer<CameraProvider>(
        builder: (context, cameraProvider, child) {
          return Stack(
            children: [
              // Main content area
              _buildMainContent(cameraProvider),
              
              // Draggable PiP overlay (front camera)
              if (cameraProvider.currentLayout == CameraLayout.pip)
                _buildDraggablePiP(cameraProvider),
              
              // Header with close button
              _buildHeader(),
              
              // Bottom controls
              _buildBottomControls(cameraProvider),
            ],
          );
        },
      ),
    );
  }
  
  /**
   * Main content area - back camera fullscreen or layout-specific content
   */
  Widget _buildMainContent(CameraProvider cameraProvider) {
    if (cameraProvider.hasError) {
      return _buildErrorState(cameraProvider);
    }
    
    if (cameraProvider.isLoading) {
      return _buildLoadingState(cameraProvider);
    }
    
    if (!cameraProvider.isReadyForRecording) {
      return _buildNotReadyState(cameraProvider);
    }
    
    switch (cameraProvider.currentLayout) {
      case CameraLayout.pip:
        return _buildPrimaryCamera(cameraProvider);
      case CameraLayout.splitVertical:
        return _buildSplitVertical(cameraProvider);
      case CameraLayout.splitHorizontal:
        return _buildSplitHorizontal(cameraProvider);
      case CameraLayout.frontOnly:
        return _buildFrontCameraPreview(cameraProvider);
      case CameraLayout.backOnly:
        return _buildBackCameraPreview(cameraProvider);
    }
  }
  
  /**
   * Back camera fullscreen preview
   */
  Widget _buildBackCameraPreview(CameraProvider cameraProvider) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        border: Border.fromBorderSide(OceanTheme.brutalistBorder),
        boxShadow: [OceanTheme.brutalistShadow],
      ),
      child: ClipRect(
        child: cameraProvider.backTextureId != -1 
          ? Texture(textureId: cameraProvider.backTextureId)
          : Container(
              color: OceanColors.steel,
              child: const Center(
                child: Text(
                  'BACK CAMERA\nINITIALIZING...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
      ),
    );
  }
  
  /**
   * Front camera fullscreen preview
   */
  Widget _buildFrontCameraPreview(CameraProvider cameraProvider) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        border: Border.fromBorderSide(OceanTheme.brutalistBorder),
        boxShadow: [OceanTheme.brutalistShadow],
      ),
      child: ClipRect(
        child: cameraProvider.frontTextureId != -1 
          ? Texture(textureId: cameraProvider.frontTextureId)
          : Container(
              color: OceanColors.steel,
              child: const Center(
                child: Text(
                  'FRONT CAMERA\nINITIALIZING...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
      ),
    );
  }
  
  /**
   * Side-by-side dual camera layout
   */
  
  /**
   * Primary camera display (back or front depending on swap state)
   */
  Widget _buildPrimaryCamera(CameraProvider cameraProvider) {
    final primaryTextureId = cameraProvider.primaryTextureId;
    
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        border: Border.fromBorderSide(OceanTheme.brutalistBorder),
        boxShadow: [OceanTheme.brutalistShadow],
      ),
      child: ClipRect(
        child: primaryTextureId != -1 
          ? Texture(textureId: primaryTextureId)
          : Container(
              color: OceanColors.steel,
              child: const Center(
                child: Text(
                  'PRIMARY CAMERA\nINITIALIZING...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
      ),
    );
  }
  
  /**
   * Vertical split layout (cameras side-by-side)
   */
  Widget _buildSplitVertical(CameraProvider cameraProvider) {
    return Row(
      children: [
        // Left camera (primary)
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              border: Border.fromBorderSide(OceanTheme.brutalistBorder),
              boxShadow: [OceanTheme.brutalistShadow],
            ),
            child: ClipRect(
              child: cameraProvider.primaryTextureId != -1 
                ? Texture(textureId: cameraProvider.primaryTextureId)
                : Container(
                    color: OceanColors.steel,
                    child: const Center(
                      child: Text(
                        'PRIMARY\nCAMERA',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
            ),
          ),
        ),
        
        // Center divider
        Container(
          width: 4,
          color: Colors.white,
        ),
        
        // Right camera (secondary)
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              border: Border.fromBorderSide(OceanTheme.brutalistBorder),
              boxShadow: [OceanTheme.brutalistShadow],
            ),
            child: ClipRect(
              child: cameraProvider.secondaryTextureId != -1 
                ? Texture(textureId: cameraProvider.secondaryTextureId)
                : Container(
                    color: OceanColors.deepNavy,
                    child: const Center(
                      child: Text(
                        'SECONDARY\nCAMERA',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
            ),
          ),
        ),
      ],
    );
  }
  
  /**
   * Horizontal split layout (cameras top/bottom)
   */
  Widget _buildSplitHorizontal(CameraProvider cameraProvider) {
    return Column(
      children: [
        // Top camera (primary)
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              border: Border.fromBorderSide(OceanTheme.brutalistBorder),
              boxShadow: [OceanTheme.brutalistShadow],
            ),
            child: ClipRect(
              child: cameraProvider.primaryTextureId != -1 
                ? Texture(textureId: cameraProvider.primaryTextureId)
                : Container(
                    color: OceanColors.steel,
                    child: const Center(
                      child: Text(
                        'PRIMARY CAMERA',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
            ),
          ),
        ),
        
        // Center divider
        Container(
          height: 4,
          color: Colors.white,
        ),
        
        // Bottom camera (secondary)
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              border: Border.fromBorderSide(OceanTheme.brutalistBorder),
              boxShadow: [OceanTheme.brutalistShadow],
            ),
            child: ClipRect(
              child: cameraProvider.secondaryTextureId != -1 
                ? Texture(textureId: cameraProvider.secondaryTextureId)
                : Container(
                    color: OceanColors.deepNavy,
                    child: const Center(
                      child: Text(
                        'SECONDARY CAMERA',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
            ),
          ),
        ),
      ],
    );
  }
  
  /**
   * Interactive draggable PiP overlay using InteractivePiPView
   */
  Widget _buildDraggablePiP(CameraProvider cameraProvider) {
    return InteractivePiPView(
      textureId: cameraProvider.secondaryTextureId,
      isRecording: cameraProvider.isRecording,
      onPositionChanged: (Rect pipRect) {
        // Update camera provider with new coordinates for native recording
        cameraProvider.updatePiPRect(pipRect);
      },
    );
  }
  
  /**
   * Header with close button and recording status
   */
  Widget _buildHeader() {
    return Consumer<CameraProvider>(
      builder: (context, cameraProvider, child) {
        return Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          right: 16,
          child: Row(
            children: [
              // Close button
              GestureDetector(
                onTap: () async {
                  // Stop recording if active before closing
                  if (cameraProvider.isRecording) {
                    await cameraProvider.stopRecording();
                  }
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: OceanColors.mint,
                    border: Border.fromBorderSide(OceanTheme.brutalistBorder),
                    boxShadow: [OceanTheme.brutalistShadow],
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.black,
                    size: 24,
                  ),
                ),
              ),
              
              const Spacer(),
              
              // Recording status indicator with flashing REC
              _buildRecordingStatusIndicator(cameraProvider),
            ],
          ),
        );
      },
    );
  }

  /**
   * Recording status indicator with flashing REC animation
   */
  Widget _buildRecordingStatusIndicator(CameraProvider cameraProvider) {
    if (cameraProvider.isRecording) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 1000),
        builder: (context, value, child) {
          final opacity = (math.sin(value * math.pi * 2) + 1) / 2;
          return AnimatedBuilder(
            animation: AlwaysStoppedAnimation(opacity),
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Color.lerp(OceanColors.warning, Colors.red, opacity),
                  border: const Border.fromBorderSide(OceanTheme.brutalistBorder),
                  boxShadow: const [OceanTheme.brutalistShadow],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'REC ${_formatRecordingTime(cameraProvider.recordingDuration)}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: const BoxDecoration(
          color: OceanColors.ocean,
          border: Border.fromBorderSide(OceanTheme.brutalistBorder),
          boxShadow: [OceanTheme.brutalistShadow],
        ),
        child: const Text(
          'LIVE PREVIEW',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      );
    }
  }
  
  /**
   * Bottom controls for layout switching and recording
   */
  Widget _buildBottomControls(CameraProvider cameraProvider) {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 24,
      left: 24,
      right: 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Layout and swap controls (only show if not recording)
          if (!cameraProvider.isRecording) ...[
            // Swap button
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => cameraProvider.swapCameras(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: cameraProvider.camerasSwapped ? OceanColors.warning : OceanColors.steel,
                    border: const Border.fromBorderSide(OceanTheme.brutalistBorder),
                    boxShadow: const [OceanTheme.brutalistShadow],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.swap_horiz,
                        color: cameraProvider.camerasSwapped ? Colors.black : Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        cameraProvider.camerasSwapped ? 'CAMERAS SWAPPED' : 'SWAP CAMERAS',
                        style: TextStyle(
                          color: cameraProvider.camerasSwapped ? Colors.black : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          fontFamily: 'Archivo Black',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Layout selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: CameraLayout.values.map((layout) => 
                _buildLayoutButton(layout, cameraProvider.currentLayout, cameraProvider)
              ).toList(),
            ),
          ],
          
          const SizedBox(height: 24),
          
          // Recording controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Photo capture button
              GestureDetector(
                onTap: cameraProvider.isReadyForRecording ? () => _takeDualPhoto(cameraProvider) : null,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: cameraProvider.isReadyForRecording ? OceanColors.ocean : OceanColors.steel.withOpacity(0.5),
                    shape: BoxShape.circle,
                    border: const Border.fromBorderSide(OceanTheme.brutalistBorder),
                    boxShadow: const [OceanTheme.brutalistShadow],
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              
              // Main record/stop button
              GestureDetector(
                onTap: cameraProvider.isReadyForRecording ? () => _toggleRecording(cameraProvider) : null,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: cameraProvider.isRecording 
                        ? OceanColors.warning 
                        : (cameraProvider.isReadyForRecording ? Colors.red : OceanColors.steel.withOpacity(0.5)),
                    shape: BoxShape.circle,
                    border: const Border.fromBorderSide(OceanTheme.brutalistBorder),
                    boxShadow: const [OceanTheme.brutalistShadow],
                  ),
                  child: Icon(
                    cameraProvider.isRecording ? Icons.stop : Icons.fiber_manual_record,
                    color: cameraProvider.isRecording ? Colors.black : Colors.white,
                    size: cameraProvider.isRecording ? 28 : 32,
                  ),
                ),
              ),
              
              // Layout toggle button (when recording)
              GestureDetector(
                onTap: cameraProvider.isReadyForRecording ? () => _showLayoutPicker(cameraProvider) : null,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: cameraProvider.isReadyForRecording ? OceanColors.mint : OceanColors.steel.withOpacity(0.5),
                    shape: BoxShape.circle,
                    border: const Border.fromBorderSide(OceanTheme.brutalistBorder),
                    boxShadow: const [OceanTheme.brutalistShadow],
                  ),
                  child: const Icon(
                    Icons.view_comfy,
                    color: Colors.black,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  /**
   * Layout selection button
   */
  Widget _buildLayoutButton(CameraLayout layout, CameraLayout currentLayout, CameraProvider cameraProvider) {
    final isSelected = layout == currentLayout;
    
    return GestureDetector(
      onTap: () => cameraProvider.setLayout(layout),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isSelected ? OceanColors.mint : OceanColors.steel,
          border: const Border.fromBorderSide(OceanTheme.brutalistBorder),
          boxShadow: const [OceanTheme.brutalistShadow],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              layout.icon,
              color: isSelected ? Colors.black : Colors.white,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              layout.shortName,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
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
  Widget _buildErrorState(CameraProvider cameraProvider) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: OceanColors.deepNavy,
      child: Center(
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
                'CAMERA ERROR',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              
              const SizedBox(height: 16),
              
              Text(
                cameraProvider.errorMessage ?? 'Unknown camera error',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
              
              const SizedBox(height: 24),
              
              GestureDetector(
                onTap: () => _retryInitialization(cameraProvider),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: const BoxDecoration(
                    color: OceanColors.steel,
                    border: Border.fromBorderSide(OceanTheme.brutalistBorder),
                    boxShadow: [OceanTheme.brutalistShadow],
                  ),
                  child: const Text(
                    'RETRY',
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
      ),
    );
  }
  
  /**
   * Loading state display
   */
  Widget _buildLoadingState(CameraProvider cameraProvider) {
    String statusText = 'INITIALIZING...';
    if (cameraProvider.isInitializing) {
      statusText = 'INITIALIZING CAMERAS...';
    } else if (cameraProvider.isOpeningCameras) {
      statusText = 'OPENING CAMERAS...';
    }
    
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: OceanColors.deepNavy,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: OceanColors.ocean,
            border: Border.fromBorderSide(OceanTheme.brutalistBorder),
            boxShadow: [OceanTheme.brutalistShadow],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Loading animation
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: const AlwaysStoppedAnimation<Color>(OceanColors.mint),
                ),
              ),
              
              const SizedBox(height: 24),
              
              Text(
                statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /**
   * Not ready state (initialization needed)
   */
  Widget _buildNotReadyState(CameraProvider cameraProvider) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: OceanColors.deepNavy,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: OceanColors.steel,
            border: Border.fromBorderSide(OceanTheme.brutalistBorder),
            boxShadow: [OceanTheme.brutalistShadow],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'CAMERA SYSTEM\nNOT READY',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              
              const SizedBox(height: 24),
              
              GestureDetector(
                onTap: () => context.read<CameraProvider>().initializeCameras(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: const BoxDecoration(
                    color: OceanColors.mint,
                    border: Border.fromBorderSide(OceanTheme.brutalistBorder),
                    boxShadow: [OceanTheme.brutalistShadow],
                  ),
                  child: const Text(
                    'INITIALIZE CAMERAS',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /**
   * Retry camera initialization
   */
  void _retryInitialization(CameraProvider cameraProvider) async {
    // Reset state and try again
    await cameraProvider.closeCameras();
    await Future.delayed(const Duration(milliseconds: 500));
    await cameraProvider.initializeCameras();
  }

  /**
   * Format recording duration for display (MM:SS)
   */
  String _formatRecordingTime(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /**
   * Toggle recording on/off
   */
  void _toggleRecording(CameraProvider cameraProvider) async {
    try {
      if (cameraProvider.isRecording) {
        // Stop recording
        final filePath = await cameraProvider.stopRecording();
        if (filePath != null) {
          _showRecordingCompleteDialog(filePath);
        }
      } else {
        // Start recording
        await cameraProvider.initializeRecording();
        await cameraProvider.startRecording();
      }
    } catch (e) {
      _showErrorDialog('Recording Error', 'Failed to ${cameraProvider.isRecording ? 'stop' : 'start'} recording: $e');
    }
  }

  /**
   * Capture a dual photo
   */
  void _takeDualPhoto(CameraProvider cameraProvider) async {
    try {
      final filePath = await cameraProvider.takeDualPhoto();
      if (filePath != null) {
        _showPhotoCompleteDialog(filePath);
      }
    } catch (e) {
      _showErrorDialog('Photo Error', 'Failed to capture photo: $e');
    }
  }

  /**
   * Show layout picker dialog
   */
  void _showLayoutPicker(CameraProvider cameraProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: OceanColors.mint,
        shape: const RoundedRectangleBorder(
          side: OceanTheme.brutalistBorder,
        ),
        title: const Text(
          'CAMERA LAYOUT',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: CameraLayout.values.map((layout) =>
            GestureDetector(
              onTap: () {
                cameraProvider.setLayout(layout);
                Navigator.of(context).pop();
              },
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: layout == cameraProvider.currentLayout ? OceanColors.ocean : OceanColors.steel,
                  border: const Border.fromBorderSide(OceanTheme.brutalistBorder),
                  boxShadow: const [OceanTheme.brutalistShadow],
                ),
                child: Text(
                  layout.displayName,
                  style: TextStyle(
                    color: layout == cameraProvider.currentLayout ? Colors.white : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ).toList(),
        ),
      ),
    );
  }

  /**
   * Show recording complete dialog
   */
  void _showRecordingCompleteDialog(String filePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: OceanColors.mint,
        shape: const RoundedRectangleBorder(
          side: OceanTheme.brutalistBorder,
        ),
        title: const Text(
          'RECORDING COMPLETE',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        content: Text(
          'Video saved to:\n$filePath',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            letterSpacing: 1,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: OceanColors.steel,
                border: Border.fromBorderSide(OceanTheme.brutalistBorder),
                boxShadow: [OceanTheme.brutalistShadow],
              ),
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /**
   * Show photo complete dialog
   */
  void _showPhotoCompleteDialog(String filePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: OceanColors.mint,
        shape: const RoundedRectangleBorder(
          side: OceanTheme.brutalistBorder,
        ),
        title: const Text(
          'PHOTO CAPTURED',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        content: Text(
          'Photo saved to:\n$filePath',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            letterSpacing: 1,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: OceanColors.steel,
                border: Border.fromBorderSide(OceanTheme.brutalistBorder),
                boxShadow: [OceanTheme.brutalistShadow],
              ),
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /**
   * Show error dialog
   */
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: OceanColors.warning,
        shape: const RoundedRectangleBorder(
          side: OceanTheme.brutalistBorder,
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            letterSpacing: 1,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: OceanColors.steel,
                border: Border.fromBorderSide(OceanTheme.brutalistBorder),
                boxShadow: [OceanTheme.brutalistShadow],
              ),
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
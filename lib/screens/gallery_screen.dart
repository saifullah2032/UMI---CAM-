import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/gallery_provider.dart';
import '../theme/ocean_colors.dart';
import '../theme/ocean_theme.dart';
import '../widgets/media_viewer.dart';

/**
 * GalleryScreen - Neo-Brutalist media vault for UMI 海 - CAM
 * 
 * Features the "Bolted Frame" Industrial Ocean design:
 * - 2-column scrollable grid with "screw-head" corner details
 * - Light Aqua background with 3px black borders and 5x5 shadows
 * - Type indicators (VID/IMG) in Archivo Black typography
 * - Smooth thumbnail loading with video preview generation
 * - Full-screen viewer integration with share/delete actions
 */
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({Key? key}) : super(key: key);

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  @override
  void initState() {
    super.initState();
    _initializeGallery();
  }

  void _initializeGallery() async {
    // Use listen: false to prevent immediate rebuild during initState
    final galleryProvider = Provider.of<GalleryProvider>(context, listen: false);
    if (!galleryProvider.isInitialized) {
      await galleryProvider.initialize();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OceanColors.deepNavy,
      appBar: _buildAppBar(),
      body: Consumer<GalleryProvider>(
        builder: (context, galleryProvider, child) {
          return Column(
            children: [
              // Gallery statistics header
              _buildStatsHeader(galleryProvider),
              
              // Media grid content
              Expanded(
                child: _buildContent(galleryProvider),
              ),
            ],
          );
        },
      ),
    );
  }

  /**
   * Neo-Brutalist app bar with refresh action
   */
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: OceanColors.ocean,
      elevation: 0,
      title: const Text(
        'MEDIA VAULT',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 3,
          fontFamily: 'Archivo Black',
        ),
      ),
      centerTitle: true,
      actions: [
        // Refresh button
        Consumer<GalleryProvider>(
          builder: (context, galleryProvider, child) {
            return GestureDetector(
              onTap: galleryProvider.isLoading ? null : () => galleryProvider.refresh(),
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: OceanColors.mint,
                  border: Border.fromBorderSide(OceanTheme.brutalistBorder),
                  boxShadow: [OceanTheme.brutalistShadow],
                ),
                child: galleryProvider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      )
                    : const Icon(
                        Icons.refresh,
                        color: Colors.black,
                        size: 20,
                      ),
              ),
            );
          },
        ),
      ],
    );
  }

  /**
   * Statistics header showing media counts and storage
   */
  Widget _buildStatsHeader(GalleryProvider galleryProvider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: OceanColors.steel,
        border: Border.fromBorderSide(OceanTheme.brutalistBorder),
        boxShadow: [OceanTheme.brutalistShadow],
      ),
      child: Column(
        children: [
          Text(
            'STORAGE MANIFEST',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              fontFamily: 'Archivo Black',
            ),
          ),
          
          const SizedBox(height: 12),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem('VIDEOS', '${galleryProvider.totalVideoCount}', Icons.videocam),
              _buildStatItem('PHOTOS', '${galleryProvider.totalPhotoCount}', Icons.photo_camera),
              _buildStatItem('STORAGE', galleryProvider.formattedTotalSize, Icons.storage),
            ],
          ),
        ],
      ),
    );
  }

  /**
   * Individual statistic item
   */
  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: OceanColors.mint,
            border: Border.fromBorderSide(OceanTheme.brutalistBorder),
          ),
          child: Icon(
            icon,
            size: 16,
            color: Colors.black,
          ),
        ),
        
        const SizedBox(height: 4),
        
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 8,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  /**
   * Main content area with different states
   */
  Widget _buildContent(GalleryProvider galleryProvider) {
    if (galleryProvider.errorMessage != null) {
      return _buildErrorState(galleryProvider);
    }
    
    if (galleryProvider.isLoading && !galleryProvider.hasMedia) {
      return _buildLoadingState();
    }
    
    if (!galleryProvider.hasMedia) {
      return _buildEmptyState();
    }
    
    return _buildMediaGrid(galleryProvider);
  }

  /**
   * Error state display
   */
  Widget _buildErrorState(GalleryProvider galleryProvider) {
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
              'GALLERY ERROR',
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
              galleryProvider.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
                letterSpacing: 1,
              ),
            ),
            
            const SizedBox(height: 24),
            
            GestureDetector(
              onTap: () => galleryProvider.refresh(),
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
    );
  }

  /**
   * Loading state display
   */
  Widget _buildLoadingState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: OceanColors.ocean,
          border: Border.fromBorderSide(OceanTheme.brutalistBorder),
          boxShadow: [OceanTheme.brutalistShadow],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(OceanColors.mint),
              ),
            ),
            
            const SizedBox(height: 24),
            
            const Text(
              'SCANNING MEDIA VAULT...',
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
   * Empty state when no media found
   */
  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: OceanColors.steel,
          border: Border.fromBorderSide(OceanTheme.brutalistBorder),
          boxShadow: [OceanTheme.brutalistShadow],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: OceanColors.mint,
                border: Border.fromBorderSide(OceanTheme.brutalistBorder),
              ),
              child: const Icon(
                Icons.photo_library_outlined,
                size: 40,
                color: Colors.black,
              ),
            ),
            
            const SizedBox(height: 24),
            
            const Text(
              'MEDIA VAULT EMPTY',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                fontFamily: 'Archivo Black',
              ),
            ),
            
            const SizedBox(height: 16),
            
            const Text(
              'Record videos or capture photos\nto populate your media vault.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                letterSpacing: 1,
              ),
            ),
            
            const SizedBox(height: 24),
            
            GestureDetector(
              onTap: () => Navigator.of(context).pushReplacementNamed('/recording'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: const BoxDecoration(
                  color: OceanColors.warning,
                  border: Border.fromBorderSide(OceanTheme.brutalistBorder),
                  boxShadow: [OceanTheme.brutalistShadow],
                ),
                child: const Text(
                  'START RECORDING',
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
    );
  }

  /**
   * 2-column media grid with "Bolted Frame" design
   */
  Widget _buildMediaGrid(GalleryProvider galleryProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8, // Slightly taller than square
        ),
        itemCount: galleryProvider.mediaItems.length,
        itemBuilder: (context, index) {
          final mediaItem = galleryProvider.mediaItems[index];
          return _buildBoltedMediaCard(mediaItem, galleryProvider);
        },
      ),
    );
  }

  /**
   * Individual "Bolted Frame" media card with Industrial details
   */
  Widget _buildBoltedMediaCard(MediaItem mediaItem, GalleryProvider galleryProvider) {
    return GestureDetector(
      onTap: () => _openMediaViewer(mediaItem),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFB9E5E8), // Light Aqua background
          border: Border.fromBorderSide(OceanTheme.brutalistBorder),
          boxShadow: [OceanTheme.brutalistShadow],
        ),
        child: Stack(
          children: [
            // Media content (thumbnail or icon)
            _buildMediaContent(mediaItem),
            
            // Industrial screw heads in corners
            _buildScrewHeads(),
            
            // Media type indicator
            _buildTypeIndicator(mediaItem),
            
            // Media info overlay
            _buildMediaInfo(mediaItem),
          ],
        ),
      ),
    );
  }

  /**
   * Media content (thumbnail for videos, icon for photos)
   */
  Widget _buildMediaContent(MediaItem mediaItem) {
    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.all(12), // Space for screw heads
        child: ClipRect(
          child: _buildThumbnail(mediaItem),
        ),
      ),
    );
  }

  /**
   * Thumbnail display with loading states
   */
  Widget _buildThumbnail(MediaItem mediaItem) {
    if (mediaItem.type == MediaType.video) {
      if (mediaItem.thumbnailData != null) {
        return Image.memory(
          mediaItem.thumbnailData!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      } else if (mediaItem.isLoadingThumbnail) {
        return Container(
          color: OceanColors.steel,
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(OceanColors.mint),
              ),
            ),
          ),
        );
      } else {
        return Container(
          color: OceanColors.steel,
          child: const Center(
            child: Icon(
              Icons.videocam,
              size: 32,
              color: Colors.white,
            ),
          ),
        );
      }
    } else {
      // Photo thumbnail
      return Image.file(
        mediaItem.file,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: OceanColors.steel,
            child: const Center(
              child: Icon(
                Icons.photo,
                size: 32,
                color: Colors.white,
              ),
            ),
          );
        },
      );
    }
  }

  /**
   * Industrial screw heads in all four corners
   */
  Widget _buildScrewHeads() {
    const screwSize = 12.0;
    
    return Stack(
      children: [
        // Top-left screw
        Positioned(
          top: 4,
          left: 4,
          child: _buildScrewHead(),
        ),
        
        // Top-right screw  
        Positioned(
          top: 4,
          right: 4,
          child: _buildScrewHead(),
        ),
        
        // Bottom-left screw
        Positioned(
          bottom: 4,
          left: 4,
          child: _buildScrewHead(),
        ),
        
        // Bottom-right screw
        Positioned(
          bottom: 4,
          right: 4,
          child: _buildScrewHead(),
        ),
      ],
    );
  }

  /**
   * Individual screw head with cross-head detail
   */
  Widget _buildScrewHead() {
    return Container(
      width: 12,
      height: 12,
      decoration: const BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
      ),
      child: CustomPaint(
        painter: ScrewHeadPainter(),
      ),
    );
  }

  /**
   * Media type indicator (VID/IMG)
   */
  Widget _buildTypeIndicator(MediaItem mediaItem) {
    return Positioned(
      bottom: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: mediaItem.type == MediaType.video ? OceanColors.warning : OceanColors.mint,
          border: const Border.fromBorderSide(BorderSide(color: Colors.black, width: 2)),
        ),
        child: Text(
          mediaItem.type.displayName,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            fontFamily: 'Archivo Black',
          ),
        ),
      ),
    );
  }

  /**
   * Media information overlay
   */
  Widget _buildMediaInfo(MediaItem mediaItem) {
    return Positioned(
      bottom: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              mediaItem.formattedSize,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              mediaItem.timeAgo,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 6,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /**
   * Open full-screen media viewer
   */
  void _openMediaViewer(MediaItem mediaItem) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MediaViewer(mediaItem: mediaItem),
        fullscreenDialog: true,
      ),
    );
  }
}

/**
 * Custom painter for screw head cross detail
 */
class ScrewHeadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
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
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

import '../providers/gallery_provider.dart';
import '../theme/ocean_colors.dart';
import '../theme/ocean_theme.dart';

/**
 * MediaViewer - Full-screen Neo-Brutalist media viewer for UMI 海 - CAM
 * 
 * Features:
 * - Full-screen video playback with custom Industrial Ocean controls
 * - High-resolution photo viewing with zoom support
 * - Neo-Brutalist delete and share action buttons
 * - Consistent 2px black borders and hard shadows
 * - Immersive viewing experience with overlay UI
 */
class MediaViewer extends StatefulWidget {
  final MediaItem mediaItem;

  const MediaViewer({
    Key? key,
    required this.mediaItem,
  }) : super(key: key);

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  // Video player components
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isVideoInitialized = false;
  bool _isVideoLoading = false;
  String? _videoError;

  // UI state
  bool _showControls = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    if (widget.mediaItem.type == MediaType.video) {
      _initializeVideo();
    }
    
    // Auto-hide controls after 3 seconds
    _startControlsTimer();
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  /**
   * Initialize video player for video files
   */
  Future<void> _initializeVideo() async {
    if (widget.mediaItem.type != MediaType.video) return;

    setState(() {
      _isVideoLoading = true;
      _videoError = null;
    });

    try {
      _videoController = VideoPlayerController.file(widget.mediaItem.file);
      
      await _videoController!.initialize();
      
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        aspectRatio: _videoController!.value.aspectRatio,
        autoPlay: false,
        looping: true,
        allowMuting: true,
        allowFullScreen: false, // We're already full screen
        allowPlaybackSpeedChanging: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: OceanColors.mint,
          handleColor: OceanColors.warning,
          backgroundColor: Colors.white30,
          bufferedColor: Colors.white60,
        ),
        placeholder: Container(
          color: OceanColors.steel,
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(OceanColors.mint),
            ),
          ),
        ),
      );

      setState(() {
        _isVideoInitialized = true;
        _isVideoLoading = false;
      });

    } catch (e) {
      setState(() {
        _videoError = 'Failed to load video: $e';
        _isVideoLoading = false;
      });
    }
  }

  /**
   * Dispose video player resources
   */
  void _disposeVideo() {
    _chewieController?.dispose();
    _videoController?.dispose();
  }

  /**
   * Start timer to auto-hide controls
   */
  void _startControlsTimer() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  /**
   * Toggle controls visibility
   */
  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    
    if (_showControls) {
      _startControlsTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Media content
            _buildMediaContent(),
            
            // Overlay controls (when visible)
            if (_showControls)
              _buildOverlayControls(),
            
            // Processing indicator
            if (_isProcessing)
              _buildProcessingOverlay(),
          ],
        ),
      ),
    );
  }

  /**
   * Main media content (video or photo)
   */
  Widget _buildMediaContent() {
    return Center(
      child: widget.mediaItem.type == MediaType.video
          ? _buildVideoPlayer()
          : _buildPhotoViewer(),
    );
  }

  /**
   * Video player with custom styling
   */
  Widget _buildVideoPlayer() {
    if (_videoError != null) {
      return _buildVideoError();
    }

    if (_isVideoLoading) {
      return _buildVideoLoading();
    }

    if (!_isVideoInitialized || _chewieController == null) {
      return Container(
        color: OceanColors.steel,
        child: const Center(
          child: Text(
            'PREPARING VIDEO...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: _videoController!.value.aspectRatio,
      child: Chewie(controller: _chewieController!),
    );
  }

  /**
   * Video loading state
   */
  Widget _buildVideoLoading() {
    return Container(
      color: OceanColors.steel,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(OceanColors.mint),
              ),
            ),
            
            const SizedBox(height: 24),
            
            const Text(
              'LOADING VIDEO...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              widget.mediaItem.displayName,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /**
   * Video error state
   */
  Widget _buildVideoError() {
    return Container(
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
                'VIDEO ERROR',
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
                _videoError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
              
              const SizedBox(height: 24),
              
              GestureDetector(
                onTap: _initializeVideo,
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
   * Photo viewer with zoom support
   */
  Widget _buildPhotoViewer() {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 3.0,
      child: Image.file(
        widget.mediaItem.file,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: OceanColors.deepNavy,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: const BoxDecoration(
                  color: OceanColors.warning,
                  border: Border.fromBorderSide(OceanTheme.brutalistBorder),
                  boxShadow: [OceanTheme.brutalistShadow],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'PHOTO ERROR',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        fontFamily: 'Archivo Black',
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    const Text(
                      'Failed to load photo file',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /**
   * Overlay controls with Neo-Brutalist styling
   */
  Widget _buildOverlayControls() {
    return SafeArea(
      child: Column(
        children: [
          // Top controls
          _buildTopControls(),
          
          const Spacer(),
          
          // Bottom info
          _buildBottomInfo(),
        ],
      ),
    );
  }

  /**
   * Top control buttons
   */
  Widget _buildTopControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: OceanColors.mint,
                border: Border.fromBorderSide(BorderSide(color: Colors.black, width: 2)),
                boxShadow: [BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0)],
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.black,
                size: 24,
              ),
            ),
          ),
          
          const Spacer(),
          
          // Share button
          GestureDetector(
            onTap: _isProcessing ? null : _shareMedia,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _isProcessing ? OceanColors.steel.withOpacity(0.5) : OceanColors.ocean,
                border: const Border.fromBorderSide(BorderSide(color: Colors.black, width: 2)),
                boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0)],
              ),
              child: const Icon(
                Icons.share,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Delete button
          GestureDetector(
            onTap: _isProcessing ? null : _deleteMedia,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _isProcessing ? OceanColors.steel.withOpacity(0.5) : OceanColors.warning,
                border: const Border.fromBorderSide(BorderSide(color: Colors.black, width: 2)),
                boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0)],
              ),
              child: const Icon(
                Icons.delete,
                color: Colors.black,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /**
   * Bottom media information
   */
  Widget _buildBottomInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        border: const Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.mediaItem.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.mediaItem.type == MediaType.video ? OceanColors.warning : OceanColors.mint,
                  border: const Border.fromBorderSide(BorderSide(color: Colors.black, width: 1)),
                ),
                child: Text(
                  widget.mediaItem.type.displayName,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    fontFamily: 'Archivo Black',
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              Text(
                '${widget.mediaItem.formattedSize} • ${widget.mediaItem.timeAgo}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /**
   * Processing overlay
   */
  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
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
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(OceanColors.mint),
                ),
              ),
              
              SizedBox(height: 16),
              
              Text(
                'PROCESSING...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
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
   * Share media file
   */
  void _shareMedia() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final galleryProvider = context.read<GalleryProvider>();
      final success = await galleryProvider.shareMedia(widget.mediaItem);
      
      if (!success && mounted) {
        _showErrorDialog('Share Failed', 'Failed to share media file');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Share Error', 'Error sharing media: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  /**
   * Delete media file with confirmation
   */
  void _deleteMedia() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: OceanColors.warning,
        shape: const RoundedRectangleBorder(
          side: OceanTheme.brutalistBorder,
        ),
        title: const Text(
          'DELETE MEDIA',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            fontFamily: 'Archivo Black',
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${widget.mediaItem.displayName}"?\n\nThis action cannot be undone.',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            letterSpacing: 1,
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: const BoxDecoration(
                      color: OceanColors.steel,
                      border: Border.fromBorderSide(OceanTheme.brutalistBorder),
                      boxShadow: [OceanTheme.brutalistShadow],
                    ),
                    child: const Text(
                      'CANCEL',
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
              
              const SizedBox(width: 12),
              
              Expanded(
                child: GestureDetector(
                  onTap: _confirmDelete,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      border: Border.fromBorderSide(OceanTheme.brutalistBorder),
                      boxShadow: [OceanTheme.brutalistShadow],
                    ),
                    child: const Text(
                      'DELETE',
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
            ],
          ),
        ],
      ),
    );
  }

  /**
   * Confirm and execute delete
   */
  void _confirmDelete() async {
    Navigator.of(context).pop(); // Close confirmation dialog

    setState(() {
      _isProcessing = true;
    });

    try {
      final galleryProvider = context.read<GalleryProvider>();
      final success = await galleryProvider.deleteMedia(widget.mediaItem);
      
      if (success && mounted) {
        Navigator.of(context).pop(); // Close media viewer
      } else if (mounted) {
        _showErrorDialog('Delete Failed', 'Failed to delete media file');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Delete Error', 'Error deleting media: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
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
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            fontFamily: 'Archivo Black',
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:share_plus/share_plus.dart';

/**
 * MediaItem - Represents a media file (video or photo) with metadata
 */
class MediaItem {
  final File file;
  final MediaType type;
  final DateTime dateCreated;
  final int sizeBytes;
  final String displayName;
  Uint8List? thumbnailData;
  bool isLoadingThumbnail;

  MediaItem({
    required this.file,
    required this.type,
    required this.dateCreated,
    required this.sizeBytes,
    required this.displayName,
    this.thumbnailData,
    this.isLoadingThumbnail = false,
  });

  /// File size formatted as human readable string
  String get formattedSize {
    if (sizeBytes < 1024) return '${sizeBytes}B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)}KB';
    if (sizeBytes < 1024 * 1024 * 1024) return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  /// Duration since creation as human readable string
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(dateCreated);
    
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }

  @override
  String toString() => 'MediaItem(${file.path}, $type, $formattedSize)';
}

/**
 * Media type enumeration
 */
enum MediaType {
  video,
  photo,
}

extension MediaTypeExtension on MediaType {
  String get displayName {
    switch (this) {
      case MediaType.video:
        return 'VID';
      case MediaType.photo:
        return 'IMG';
    }
  }

  String get extension {
    switch (this) {
      case MediaType.video:
        return '.mp4';
      case MediaType.photo:
        return '.jpg';
    }
  }
}

/**
 * GalleryProvider - Manages local media files for UMI 海 - CAM
 * 
 * Features:
 * - Scans app's output folder for videos and photos
 * - Generates thumbnails for smooth grid scrolling
 * - Provides delete and share functionality
 * - Sorts media by creation date (newest first)
 * - Thread-safe thumbnail generation
 */
class GalleryProvider extends ChangeNotifier {
  static const String _tag = 'GalleryProvider';
  
  // Media state
  List<MediaItem> _mediaItems = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;
  
  // Directories
  Directory? _mediaDirectory;
  Directory? _thumbnailCacheDirectory;
  
  // Statistics
  int _totalVideoCount = 0;
  int _totalPhotoCount = 0;
  int _totalSizeBytes = 0;

  // ============================================================
  // PUBLIC GETTERS
  // ============================================================

  /// All media items sorted by date (newest first)
  List<MediaItem> get mediaItems => List.unmodifiable(_mediaItems);

  /// Only video items
  List<MediaItem> get videoItems => _mediaItems.where((item) => item.type == MediaType.video).toList();

  /// Only photo items  
  List<MediaItem> get photoItems => _mediaItems.where((item) => item.type == MediaType.photo).toList();

  /// Whether the gallery is loading
  bool get isLoading => _isLoading;

  /// Whether the gallery has been initialized
  bool get isInitialized => _isInitialized;

  /// Current error message (if any)
  String? get errorMessage => _errorMessage;

  /// Total number of videos
  int get totalVideoCount => _totalVideoCount;

  /// Total number of photos
  int get totalPhotoCount => _totalPhotoCount;

  /// Total number of media files
  int get totalMediaCount => _mediaItems.length;

  /// Total size of all media files
  int get totalSizeBytes => _totalSizeBytes;

  /// Total size formatted as human readable string
  String get formattedTotalSize {
    if (_totalSizeBytes < 1024) return '${_totalSizeBytes}B';
    if (_totalSizeBytes < 1024 * 1024) return '${(_totalSizeBytes / 1024).toStringAsFixed(1)}KB';
    if (_totalSizeBytes < 1024 * 1024 * 1024) return '${(_totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(_totalSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  /// Whether there are any media files
  bool get hasMedia => _mediaItems.isNotEmpty;

  /// Media directory path (if available)
  String? get mediaDirectoryPath => _mediaDirectory?.path;

  // ============================================================
  // INITIALIZATION
  // ============================================================

  /**
   * Initialize the gallery system
   * Creates directories and scans for existing media files
   */
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('$_tag: Already initialized');
      return;
    }

    _isLoading = true;
    _clearError();
    // Defer notification to avoid race condition during build phase
    Future.microtask(() => notifyListeners());

    try {
      debugPrint('$_tag: Initializing gallery system...');

      // Get app documents directory
      final appDocDir = await getApplicationDocumentsDirectory();
      
      // Create UMI-CAM media directory (matching VideoComposer output)
      _mediaDirectory = Directory('${appDocDir.path}/UMI-CAM');
      if (!await _mediaDirectory!.exists()) {
        await _mediaDirectory!.create(recursive: true);
        debugPrint('$_tag: Created media directory: ${_mediaDirectory!.path}');
      }

      // Create thumbnail cache directory
      final cacheDir = await getTemporaryDirectory();
      _thumbnailCacheDirectory = Directory('${cacheDir.path}/thumbnails');
      if (!await _thumbnailCacheDirectory!.exists()) {
        await _thumbnailCacheDirectory!.create(recursive: true);
        debugPrint('$_tag: Created thumbnail cache directory: ${_thumbnailCacheDirectory!.path}');
      }

      // Scan for existing media files
      await scanMediaFiles();

      _isInitialized = true;
      debugPrint('$_tag: Gallery initialization complete');

    } catch (e) {
      debugPrint('$_tag: Error during initialization: $e');
      _setError('Failed to initialize gallery: $e');
    } finally {
      _isLoading = false;
      // Defer notification to avoid race condition
      Future.microtask(() => notifyListeners());
    }
  }

  /**
   * Scan the media directory for video and photo files
   */
  Future<void> scanMediaFiles() async {
    if (_mediaDirectory == null) {
      debugPrint('$_tag: Media directory not initialized');
      return;
    }

    _isLoading = true;
    // Defer notification to avoid race condition during build phase
    Future.microtask(() => notifyListeners());

    try {
      debugPrint('$_tag: Scanning media files in ${_mediaDirectory!.path}');

      final mediaItems = <MediaItem>[];
      int totalSize = 0;

      // Scan for video files (.mp4)
      await for (final entity in _mediaDirectory!.list()) {
        if (entity is File) {
          final fileName = entity.uri.pathSegments.last.toLowerCase();
          MediaType? type;

          if (fileName.endsWith('.mp4')) {
            type = MediaType.video;
          } else if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg')) {
            type = MediaType.photo;
          }

          if (type != null) {
            final stat = await entity.stat();
            final mediaItem = MediaItem(
              file: entity,
              type: type,
              dateCreated: stat.modified,
              sizeBytes: stat.size,
              displayName: fileName,
            );

            mediaItems.add(mediaItem);
            totalSize += stat.size;

            debugPrint('$_tag: Found ${type.displayName}: $fileName (${mediaItem.formattedSize})');
          }
        }
      }

      // Sort by date created (newest first)
      mediaItems.sort((a, b) => b.dateCreated.compareTo(a.dateCreated));

      // Update state
      _mediaItems = mediaItems;
      _totalSizeBytes = totalSize;
      _calculateStatistics();

      debugPrint('$_tag: Scan complete - Found $_totalVideoCount videos, $_totalPhotoCount photos ($formattedTotalSize total)');

      // Generate thumbnails for videos (async)
      _generateThumbnails();

    } catch (e) {
      debugPrint('$_tag: Error scanning media files: $e');
      _setError('Failed to scan media files: $e');
    } finally {
      _isLoading = false;
      // Defer notification to avoid race condition
      Future.microtask(() => notifyListeners());
    }
  }

  /**
   * Refresh the media gallery
   */
  Future<void> refresh() async {
    debugPrint('$_tag: Refreshing gallery...');
    await scanMediaFiles();
  }

  // ============================================================
  // THUMBNAIL GENERATION
  // ============================================================

  /**
   * Generate thumbnails for all video files
   */
  Future<void> _generateThumbnails() async {
    final videoItems = _mediaItems.where((item) => item.type == MediaType.video && item.thumbnailData == null);
    
    if (videoItems.isEmpty) {
      debugPrint('$_tag: No videos need thumbnails');
      return;
    }

    debugPrint('$_tag: Generating thumbnails for ${videoItems.length} videos...');

    for (final item in videoItems) {
      await _generateThumbnailForItem(item);
    }
  }

  /**
   * Generate thumbnail for a specific video item
   */
  Future<void> _generateThumbnailForItem(MediaItem item) async {
    if (item.type != MediaType.video || item.isLoadingThumbnail) {
      return;
    }

    try {
      item.isLoadingThumbnail = true;
      // Defer notification to avoid race condition
      Future.microtask(() => notifyListeners());

      debugPrint('$_tag: Generating thumbnail for ${item.displayName}...');

      final thumbnailData = await VideoThumbnail.thumbnailData(
        video: item.file.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 300,
        maxHeight: 300,
        quality: 75,
      );

      if (thumbnailData != null) {
        item.thumbnailData = thumbnailData;
        debugPrint('$_tag: Thumbnail generated for ${item.displayName}');
      } else {
        debugPrint('$_tag: Failed to generate thumbnail for ${item.displayName}');
      }

    } catch (e) {
      debugPrint('$_tag: Error generating thumbnail for ${item.displayName}: $e');
    } finally {
      item.isLoadingThumbnail = false;
      // Defer notification to avoid race condition
      Future.microtask(() => notifyListeners());
    }
  }

  // ============================================================
  // MEDIA MANAGEMENT
  // ============================================================

  /**
   * Delete a media file
   */
  Future<bool> deleteMedia(MediaItem item) async {
    try {
      debugPrint('$_tag: Deleting media: ${item.displayName}');

      // Delete the file
      if (await item.file.exists()) {
        await item.file.delete();
        debugPrint('$_tag: File deleted: ${item.file.path}');
      }

      // Remove from list
      _mediaItems.remove(item);
      _calculateStatistics();
      notifyListeners();

      debugPrint('$_tag: Media deleted successfully');
      return true;

    } catch (e) {
      debugPrint('$_tag: Error deleting media: $e');
      _setError('Failed to delete media: $e');
      return false;
    }
  }

  /**
   * Share a media file
   */
  Future<bool> shareMedia(MediaItem item) async {
    try {
      debugPrint('$_tag: Sharing media: ${item.displayName}');

      if (!await item.file.exists()) {
        _setError('File not found: ${item.displayName}');
        return false;
      }

      await Share.shareXFiles(
        [XFile(item.file.path)],
        text: 'Shared from UMI 海 - CAM',
        subject: item.displayName,
      );

      debugPrint('$_tag: Media shared successfully');
      return true;

    } catch (e) {
      debugPrint('$_tag: Error sharing media: $e');
      _setError('Failed to share media: $e');
      return false;
    }
  }

  /**
   * Get detailed information about a media item
   */
  Map<String, dynamic> getMediaInfo(MediaItem item) {
    return {
      'fileName': item.displayName,
      'filePath': item.file.path,
      'fileSize': item.formattedSize,
      'dateCreated': item.dateCreated.toIso8601String(),
      'timeAgo': item.timeAgo,
      'mediaType': item.type.displayName,
      'hasThumbnail': item.thumbnailData != null,
      'isLoadingThumbnail': item.isLoadingThumbnail,
    };
  }

  // ============================================================
  // STATISTICS & UTILITIES
  // ============================================================

  /**
   * Calculate media statistics
   */
  void _calculateStatistics() {
    _totalVideoCount = _mediaItems.where((item) => item.type == MediaType.video).length;
    _totalPhotoCount = _mediaItems.where((item) => item.type == MediaType.photo).length;
    _totalSizeBytes = _mediaItems.fold(0, (sum, item) => sum + item.sizeBytes);
  }

  /**
   * Get comprehensive gallery statistics
   */
  Map<String, dynamic> getGalleryStats() {
    return {
      'totalMediaCount': totalMediaCount,
      'totalVideoCount': _totalVideoCount,
      'totalPhotoCount': _totalPhotoCount,
      'totalSizeBytes': _totalSizeBytes,
      'formattedTotalSize': formattedTotalSize,
      'mediaDirectoryPath': mediaDirectoryPath,
      'isInitialized': _isInitialized,
      'hasMedia': hasMedia,
    };
  }

  /**
   * Clear error state
   */
  void _clearError() {
    _errorMessage = null;
  }

  /**
   * Set error message
   */
  void _setError(String message) {
    _errorMessage = message;
    debugPrint('$_tag: Error - $message');
  }

  @override
  void dispose() {
    debugPrint('$_tag: Disposing GalleryProvider...');
    super.dispose();
  }

  @override
  String toString() {
    return 'GalleryProvider(items: ${_mediaItems.length}, videos: $_totalVideoCount, photos: $_totalPhotoCount, size: $formattedTotalSize)';
  }
}
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/camera_provider.dart';
import '../theme/ocean_colors.dart';
import '../theme/ocean_theme.dart';

/**
 * InteractivePiPView - Draggable and resizable Picture-in-Picture window
 * 
 * Features Industrial Ocean Neo-Brutalist design with:
 * - Smooth drag functionality with gesture detection
 * - Corner resize handle styled as industrial bolt
 * - Boundary constraints to keep window within screen
 * - 3px solid black borders with 5px hard shadows
 * - Real-time coordinate updates to native recording system
 */
class InteractivePiPView extends StatefulWidget {
  final int textureId;
  final bool isRecording;
  final Function(Rect pipRect)? onPositionChanged;
  
  const InteractivePiPView({
    Key? key,
    required this.textureId,
    this.isRecording = false,
    this.onPositionChanged,
  }) : super(key: key);

  @override
  State<InteractivePiPView> createState() => _InteractivePiPViewState();
}

class _InteractivePiPViewState extends State<InteractivePiPView> 
    with TickerProviderStateMixin {
  
  // PiP position and size state
  Offset _position = const Offset(20, 100);
  Size _size = const Size(120, 160);
  
  // Interaction state
  bool _isDragging = false;
  bool _isResizing = false;
  
  // Animation controllers
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  
  // Constraints
  static const double _minWidth = 80;
  static const double _minHeight = 100;
  static const double _maxWidth = 200;
  static const double _maxHeight = 300;
  static const double _resizeHandleSize = 24;
  static const double _boundaryPadding = 10;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize scale animation for interaction feedback
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
  }
  
  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Positioned(
          left: _position.dx,
          top: _position.dy,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: _buildPiPWindow(screenSize),
          ),
        );
      },
    );
  }
  
  /**
   * Main PiP window with drag and resize capabilities
   */
  Widget _buildPiPWindow(Size screenSize) {
    return GestureDetector(
      onPanStart: _onDragStart,
      onPanUpdate: (details) => _onDragUpdate(details, screenSize),
      onPanEnd: _onDragEnd,
      child: Container(
        width: _size.width,
        height: _size.height,
        decoration: BoxDecoration(
          color: OceanColors.steel,
          border: Border.all(
            color: Colors.black,
            width: 3,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              offset: Offset(5, 5),
              blurRadius: 0,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Camera texture preview
            _buildCameraPreview(),
            
            // Industrial corner screws
            _buildCornerScrews(),
            
            // Resize handle (bottom-right)
            _buildResizeHandle(screenSize),
            
            // Interaction overlay
            if (_isDragging || _isResizing)
              _buildInteractionOverlay(),
          ],
        ),
      ),
    );
  }
  
  /**
   * Camera texture preview content
   */
  Widget _buildCameraPreview() {
    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.all(8), // Space for corner screws
        child: ClipRect(
          child: widget.textureId >= 0
              ? Texture(textureId: widget.textureId)
              : Container(
                  color: OceanColors.deepNavy,
                  child: const Center(
                    child: Icon(
                      Icons.camera_front,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
  
  /**
   * Industrial corner screws for authentic neo-brutalist feel
   */
  Widget _buildCornerScrews() {
    return Stack(
      children: [
        // Top-left screw
        const Positioned(
          top: 4,
          left: 4,
          child: _IndustrialScrew(),
        ),
        
        // Top-right screw  
        const Positioned(
          top: 4,
          right: 4,
          child: _IndustrialScrew(),
        ),
        
        // Bottom-left screw
        const Positioned(
          bottom: 4,
          left: 4,
          child: _IndustrialScrew(),
        ),
        
        // Bottom-right reserved for resize handle
      ],
    );
  }
  
  /**
   * Resize handle styled as industrial bolt
   */
  Widget _buildResizeHandle(Size screenSize) {
    return Positioned(
      bottom: 0,
      right: 0,
      child: GestureDetector(
        onPanStart: _onResizeStart,
        onPanUpdate: (details) => _onResizeUpdate(details, screenSize),
        onPanEnd: _onResizeEnd,
        child: Container(
          width: _resizeHandleSize,
          height: _resizeHandleSize,
          decoration: const BoxDecoration(
            color: OceanColors.warning,
            border: Border.fromBorderSide(
              BorderSide(color: Colors.black, width: 2)
            ),
          ),
          child: const Icon(
            Icons.open_in_full,
            color: Colors.black,
            size: 12,
          ),
        ),
      ),
    );
  }
  
  /**
   * Semi-transparent overlay during interactions
   */
  Widget _buildInteractionOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: OceanColors.mint.withOpacity(0.3),
          border: Border.all(
            color: OceanColors.warning,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            _isDragging ? 'MOVING' : 'RESIZING',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              fontFamily: 'Archivo Black',
            ),
          ),
        ),
      ),
    );
  }
  
  // ============================================================
  // DRAG INTERACTION HANDLERS
  // ============================================================
  
  void _onDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
    _scaleController.forward();
  }
  
  void _onDragUpdate(DragUpdateDetails details, Size screenSize) {
    setState(() {
      // Calculate new position
      final newPosition = _position + details.delta;
      
      // Apply boundary constraints
      _position = Offset(
        math.max(
          _boundaryPadding,
          math.min(
            screenSize.width - _size.width - _boundaryPadding,
            newPosition.dx,
          ),
        ),
        math.max(
          _boundaryPadding + kToolbarHeight, // Account for status bar
          math.min(
            screenSize.height - _size.height - _boundaryPadding - 100, // Account for bottom controls
            newPosition.dy,
          ),
        ),
      );
    });
    
    // Notify position change for native recording coordination
    _notifyPositionChange();
  }
  
  void _onDragEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });
    _scaleController.reverse();
  }
  
  // ============================================================
  // RESIZE INTERACTION HANDLERS
  // ============================================================
  
  void _onResizeStart(DragStartDetails details) {
    setState(() {
      _isResizing = true;
    });
    _scaleController.forward();
  }
  
  void _onResizeUpdate(DragUpdateDetails details, Size screenSize) {
    setState(() {
      // Calculate new size based on drag delta
      final newWidth = _size.width + details.delta.dx;
      final newHeight = _size.height + details.delta.dy;
      
      // Apply size constraints
      _size = Size(
        math.max(
          _minWidth,
          math.min(
            _maxWidth,
            math.min(
              screenSize.width - _position.dx - _boundaryPadding,
              newWidth,
            ),
          ),
        ),
        math.max(
          _minHeight,
          math.min(
            _maxHeight,
            math.min(
              screenSize.height - _position.dy - _boundaryPadding - 100,
              newHeight,
            ),
          ),
        ),
      );
    });
    
    // Notify position change for native recording coordination
    _notifyPositionChange();
  }
  
  void _onResizeEnd(DragEndDetails details) {
    setState(() {
      _isResizing = false;
    });
    _scaleController.reverse();
  }
  
  // ============================================================
  // COORDINATE SYSTEM INTEGRATION
  // ============================================================
  
  /**
   * Notify native system of PiP position changes for recording coordination
   */
  void _notifyPositionChange() {
    if (widget.onPositionChanged != null) {
      final pipRect = Rect.fromLTWH(
        _position.dx,
        _position.dy,
        _size.width,
        _size.height,
      );
      
      widget.onPositionChanged!(pipRect);
    }
  }
  
  /**
   * Get current PiP rectangle for external access
   */
  Rect getCurrentRect() {
    return Rect.fromLTWH(
      _position.dx,
      _position.dy,
      _size.width,
      _size.height,
    );
  }
  
  /**
   * Set PiP position programmatically (for layout presets)
   */
  void setPosition(Offset position, {Size? size}) {
    setState(() {
      _position = position;
      if (size != null) {
        _size = size;
      }
    });
    _notifyPositionChange();
  }
  
  /**
   * Animate to new position (for layout transitions)
   */
  void animateToPosition(Offset targetPosition, {Size? targetSize}) {
    // TODO: Implement smooth animation between positions
    // This would be used for layout preset transitions
  }
}

/**
 * Industrial screw widget for corner details
 */
class _IndustrialScrew extends StatelessWidget {
  const _IndustrialScrew();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: const BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
      ),
      child: CustomPaint(
        painter: _ScrewPainter(),
      ),
    );
  }
}

/**
 * Custom painter for screw cross-head detail
 */
class _ScrewPainter extends CustomPainter {
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
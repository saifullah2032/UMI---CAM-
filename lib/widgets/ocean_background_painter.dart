import 'package:flutter/material.dart';
import '../theme/ocean_colors.dart';

/// Custom painter for water ripple texture and sea illustrations
/// Creates minimalist line-art background elements with performance optimizations
class OceanBackgroundPainter extends CustomPainter {
  
  // Cache paint objects to avoid recreation
  static final Paint _basePaint = Paint()
    ..color = OceanColors.illustrationBlue
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
    
  static final Paint _ripplePaint = Paint()
    ..color = OceanColors.illustrationBlue.withOpacity(0.1)
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;
    
  static final Paint _fishPaint = Paint()
    ..color = OceanColors.illustrationBlue.withOpacity(0.15)
    ..strokeWidth = 1.2
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
    
  static final Paint _seaweedPaint = Paint()
    ..color = OceanColors.illustrationBlue.withOpacity(0.12)
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  
  // Pre-calculated constants for performance
  static const double _rippleSpacing = 0.12;
  static const double _waveSegmentWidth = 0.25;
  static const int _rippleCount = 8;
  static const int _seaweedSegments = 4;
  
  @override
  void paint(Canvas canvas, Size size) {
    // Early return for zero-size canvas
    if (size.width <= 0 || size.height <= 0) return;
    
    // Draw subtle water ripples across the background
    _drawWaterRipples(canvas, size);
    
    // Draw minimalist sea creatures
    _drawSeaIllustrations(canvas, size);
  }
  
  /// Draw subtle water ripple patterns with optimized calculations
  void _drawWaterRipples(Canvas canvas, Size size) {
    final double baseY = size.height * 0.15;
    final double rippleSpacing = size.height * _rippleSpacing;
    final double segmentWidth = size.width * _waveSegmentWidth;
    final double segmentControlWidth = size.width * 0.125;
    
    // Pre-calculate wave positions for better performance
    for (int i = 0; i < _rippleCount; i++) {
      final double y = baseY + (i * rippleSpacing);
      final double waveHeight = 8.0 + (i * 2.0);
      final Path path = Path();
      
      path.moveTo(0, y);
      
      // Optimized wave generation with fewer calculations
      for (double x = 0; x <= size.width; x += segmentWidth) {
        path.quadraticBezierTo(
          x + segmentControlWidth, 
          y - waveHeight,
          x + segmentWidth, 
          y,
        );
      }
      
      canvas.drawPath(path, _ripplePaint);
    }
  }
  
  /// Draw minimalist line-art sea creatures and seaweed with cached positions
  void _drawSeaIllustrations(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    
    // Use pre-calculated positions to avoid repeated calculations
    _drawFish(canvas, width * 0.75, height * 0.25);
    _drawFish(canvas, width * 0.2, height * 0.7);
    _drawFish(canvas, width * 0.85, height * 0.55);
    
    _drawSeaweed(canvas, width * 0.1, height * 0.8);
    _drawSeaweed(canvas, width * 0.9, height * 0.75);
  }
  
  /// Draw a minimalist line-art fish with optimized path operations
  void _drawFish(Canvas canvas, double x, double y) {
    // Fish body (oval) - use drawOval instead of path for better performance
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, y),
        width: 24,
        height: 16,
      ), 
      _fishPaint
    );
    
    // Fish tail - simplified lines
    canvas.drawLine(Offset(x - 12, y), Offset(x - 20, y - 8), _fishPaint);
    canvas.drawLine(Offset(x - 12, y), Offset(x - 20, y + 8), _fishPaint);
    
    // Fish eye - direct circle draw
    canvas.drawCircle(Offset(x + 4, y - 2), 2, _fishPaint);
  }
  
  /// Draw minimalist seaweed with optimized path construction
  void _drawSeaweed(Canvas canvas, double x, double y) {
    final Path stemPath = Path();
    stemPath.moveTo(x, y);
    
    // Optimized seaweed stem with pre-calculated positions
    for (int i = 0; i < _seaweedSegments; i++) {
      final double segmentY = y - (i * 15.0);
      final double waveX = x + (i % 2 == 0 ? 5.0 : -5.0);
      
      if (i == 0) {
        stemPath.lineTo(waveX, segmentY - 15);
      } else {
        stemPath.quadraticBezierTo(waveX, segmentY, x, segmentY - 15);
      }
    }
    
    canvas.drawPath(stemPath, _seaweedPaint);
    
    // Optimized leaf drawing with direct line operations where possible
    for (int i = 1; i < _seaweedSegments; i++) {
      final double leafY = y - (i * 15.0);
      final double leafX = x + (i % 2 == 0 ? 8.0 : -8.0);
      final double leafEndX = leafX + (i % 2 == 0 ? 5 : -5);
      
      // Use simple lines instead of paths for small leaf details
      canvas.drawLine(Offset(x, leafY), Offset(leafEndX, leafY - 8), _seaweedPaint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    // Never repaint - this is a static background
    // This prevents unnecessary repaints during camera operations
    return false;
  }
  
  @override
  bool hitTest(Offset position) {
    // Disable hit testing for better performance during touch events
    return false;
  }
}
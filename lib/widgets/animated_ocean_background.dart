import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/ocean_colors.dart';

/// Animated Ocean Background Widget with Water Caustics and Swimming Fish
/// Creates a "living" background with subtle motion and light effects
class AnimatedOceanBackground extends StatefulWidget {
  const AnimatedOceanBackground({Key? key}) : super(key: key);

  @override
  State<AnimatedOceanBackground> createState() => _AnimatedOceanBackgroundState();
}

class _AnimatedOceanBackgroundState extends State<AnimatedOceanBackground>
    with TickerProviderStateMixin {
  late AnimationController _causticController;
  late AnimationController _fish1Controller;
  late AnimationController _fish2Controller;
  late AnimationController _fish3Controller;
  late AnimationController _rippleController;

  @override
  void initState() {
    super.initState();
    
    // Water caustics animation (slow, hypnotic movement)
    _causticController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
    
    // Fish swimming animations with varying speeds
    _fish1Controller = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    _fish2Controller = AnimationController(
      duration: const Duration(seconds: 25),
      vsync: this,
    )..repeat();
    
    _fish3Controller = AnimationController(
      duration: const Duration(seconds: 18),
      vsync: this,
    )..repeat();
    
    // Ripple wave animation
    _rippleController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _causticController.dispose();
    _fish1Controller.dispose();
    _fish2Controller.dispose();
    _fish3Controller.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Stack(
      children: [
        // Water caustics background
        AnimatedBuilder(
          animation: _causticController,
          builder: (context, child) {
            return CustomPaint(
              size: screenSize,
              painter: CausticsPainter(
                animationValue: _causticController.value,
              ),
            );
          },
        ),
        
        // Ripple waves
        AnimatedBuilder(
          animation: _rippleController,
          builder: (context, child) {
            return CustomPaint(
              size: screenSize,
              painter: RippleWavesPainter(
                animationValue: _rippleController.value,
              ),
            );
          },
        ),
        
        // Swimming fish 1
        AnimatedBuilder(
          animation: _fish1Controller,
          builder: (context, child) {
            return CustomPaint(
              size: screenSize,
              painter: AnimatedFishPainter(
                x: screenSize.width * 0.75,
                y: screenSize.height * 0.25,
                animationValue: _fish1Controller.value,
                speed: 1.0,
              ),
            );
          },
        ),
        
        // Swimming fish 2
        AnimatedBuilder(
          animation: _fish2Controller,
          builder: (context, child) {
            return CustomPaint(
              size: screenSize,
              painter: AnimatedFishPainter(
                x: screenSize.width * 0.2,
                y: screenSize.height * 0.7,
                animationValue: _fish2Controller.value,
                speed: 0.8,
                flipDirection: true,
              ),
            );
          },
        ),
        
        // Swimming fish 3
        AnimatedBuilder(
          animation: _fish3Controller,
          builder: (context, child) {
            return CustomPaint(
              size: screenSize,
              painter: AnimatedFishPainter(
                x: screenSize.width * 0.85,
                y: screenSize.height * 0.55,
                animationValue: _fish3Controller.value,
                speed: 0.9,
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Water Caustics Painter - Creates animated light patterns mimicking sunlight through water
class CausticsPainter extends CustomPainter {
  final double animationValue;
  
  CausticsPainter({required this.animationValue});
  
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    
    final paint = Paint()
      ..color = OceanColors.accentBlue.withOpacity(0.05)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    // Create shifting caustic patterns
    final baseOffset = animationValue * 360;
    
    for (int i = 0; i < 6; i++) {
      final angle = (baseOffset + (i * 60)) * math.pi / 180;
      final offset = Offset(
        math.cos(angle) * 30,
        math.sin(angle) * 20,
      );
      
      // Draw nested caustic circles
      for (int j = 0; j < 5; j++) {
        final radius = 20.0 + (j * 40.0) + (animationValue * 30);
        
        canvas.drawCircle(
          Offset(size.width / 2, size.height / 3) + offset,
          radius,
          paint,
        );
      }
    }
    
    // Draw horizontal light rays
    final rayPaint = Paint()
      ..color = OceanColors.accentBlue.withOpacity(0.03)
      ..strokeWidth = 0.5;
    
    for (int i = 0; i < 10; i++) {
      final y = (i * size.height / 9) + (animationValue * 40);
      final opacity = 0.03 * math.sin(animationValue * 2 * math.pi);
      
      rayPaint.color = OceanColors.accentBlue.withOpacity(opacity.abs());
      
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        rayPaint,
      );
    }
  }

  @override
  bool shouldRepaint(CausticsPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

/// Ripple Waves Painter - Creates wave-like motion across the screen
class RippleWavesPainter extends CustomPainter {
  final double animationValue;
  
  RippleWavesPainter({required this.animationValue});
  
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    
    final paint = Paint()
      ..color = OceanColors.mint.withOpacity(0.08)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    
    const rippleCount = 8;
    const rippleSpacing = 0.12;
    
    final baseY = size.height * 0.15;
    final rippleSpacingPixels = size.height * rippleSpacing;
    
    for (int i = 0; i < rippleCount; i++) {
      final y = baseY + (i * rippleSpacingPixels);
      final waveHeight = 8.0 + (i * 2.0);
      
      // Animate wave by shifting phase
      final phase = animationValue * 2 * math.pi;
      final shiftedY = y + math.sin(phase) * 3;
      
      final Path path = Path();
      path.moveTo(0, shiftedY);
      
      const segmentWidth = 0.25;
      final segmentWidthPixels = size.width * segmentWidth;
      final segmentControlWidth = size.width * 0.125;
      
      for (double x = 0; x <= size.width; x += segmentWidthPixels) {
        final controlY = shiftedY - waveHeight + (math.sin(phase + x / 100) * 2);
        
        path.quadraticBezierTo(
          x + segmentControlWidth,
          controlY,
          x + segmentWidthPixels,
          shiftedY,
        );
      }
      
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(RippleWavesPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

/// Animated Fish Painter - Draws fish that swim across the screen
class AnimatedFishPainter extends CustomPainter {
  final double x;
  final double y;
  final double animationValue;
  final double speed;
  final bool flipDirection;
  
  AnimatedFishPainter({
    required this.x,
    required this.y,
    required this.animationValue,
    this.speed = 1.0,
    this.flipDirection = false,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Calculate swimming position (left to right, looping)
    final swimX = (animationValue * speed * size.width * 2) % (size.width + 100) - 50;
    final swimY = y + math.sin(animationValue * 2 * math.pi) * 15; // Vertical bob
    
    // Save canvas state for flipping
    canvas.save();
    
    // Translate to fish position
    canvas.translate(swimX, swimY);
    
    if (flipDirection) {
      canvas.scale(-1, 1);
    }
    
    // Draw fish body
    final fishPaint = Paint()
      ..color = OceanColors.illustrationBlue.withOpacity(0.25)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    // Fish body (oval)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: 24,
        height: 16,
      ),
      fishPaint,
    );
    
    // Fish tail with flutter animation
    final tailAngle = animationValue * 4 * math.pi;
    final tailFlutter = math.sin(tailAngle) * 4;
    
    canvas.drawLine(
      const Offset(-12, 0),
      Offset(-20, -8 + tailFlutter),
      fishPaint,
    );
    canvas.drawLine(
      const Offset(-12, 0),
      Offset(-20, 8 - tailFlutter),
      fishPaint,
    );
    
    // Fish eye with highlight
    canvas.drawCircle(
      const Offset(4, -2),
      2,
      fishPaint,
    );
    
    final eyeHighlightPaint = Paint()
      ..color = OceanColors.accentBlue.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      const Offset(5, -2.5),
      0.8,
      eyeHighlightPaint,
    );
    
    // Fish gill detail
    canvas.drawLine(
      const Offset(-2, -6),
      const Offset(-2, 6),
      fishPaint,
    );
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(AnimatedFishPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.x != x ||
        oldDelegate.y != y;
  }
}

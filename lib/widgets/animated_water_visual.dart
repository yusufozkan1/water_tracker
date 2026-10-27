import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated visual representation of daily water hydration level with wave animation.
class AnimatedWaterVisual extends StatefulWidget {
  final double progress; // 0.0 to 1.0 (or greater)
  final int currentIntake;
  final int dailyGoal;

  const AnimatedWaterVisual({
    super.key,
    required this.progress,
    required this.currentIntake,
    required this.dailyGoal,
  });

  @override
  State<AnimatedWaterVisual> createState() => _AnimatedWaterVisualState();
}

class _AnimatedWaterVisualState extends State<AnimatedWaterVisual>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGoalMet = widget.currentIntake >= widget.dailyGoal && widget.dailyGoal > 0;
    final clampedProgress = widget.progress.clamp(0.0, 1.0);
    final percentage = (widget.progress * 100).round();

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer circular decorative ring
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              boxShadow: [
                BoxShadow(
                  color: isGoalMet
                      ? Colors.teal.withValues(alpha: 0.2)
                      : Colors.blue.withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),

          // Clipped circular wave animation
          ClipOval(
            child: SizedBox(
              width: 210,
              height: 210,
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _WavePainter(
                      progress: clampedProgress,
                      animationValue: _animController.value,
                      waterColor: isGoalMet
                          ? const Color(0xFF00B4D8)
                          : const Color(0xFF0288D1),
                      surfaceColor: isGoalMet
                          ? const Color(0xFF90E0EF)
                          : const Color(0xFF4FC3F7),
                    ),
                  );
                },
              ),
            ),
          ),

          // Center text overlay
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isGoalMet)
                const Icon(
                  Icons.stars_rounded,
                  color: Colors.amber,
                  size: 32,
                ),
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  color: clampedProgress > 0.55
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                  shadows: clampedProgress > 0.55
                      ? const [
                          Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 4,
                            color: Colors.black38,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${widget.currentIntake} / ${widget.dailyGoal} ml',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: clampedProgress > 0.55
                      ? Colors.white.withValues(alpha: 0.95)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              if (isGoalMet)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Goal reached! 🎉',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: clampedProgress > 0.55 ? Colors.white : Colors.teal,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double progress;
  final double animationValue;
  final Color waterColor;
  final Color surfaceColor;

  _WavePainter({
    required this.progress,
    required this.animationValue,
    required this.waterColor,
    required this.surfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) {
      // Empty
      return;
    }

    final width = size.width;
    final height = size.height;
    final baseHeight = height * (1.0 - progress);

    final wavePaintBack = Paint()
      ..color = surfaceColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    final wavePaintFront = Paint()
      ..color = waterColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    // Draw background wave (offset phase)
    final backPath = Path();
    backPath.moveTo(0, height);
    for (double x = 0; x <= width; x++) {
      final y = baseHeight +
          math.sin((x / width * 2 * math.pi) + (animationValue * 2 * math.pi) + 1.5) *
              6.0;
      backPath.lineTo(x, y);
    }
    backPath.lineTo(width, height);
    backPath.close();
    canvas.drawPath(backPath, wavePaintBack);

    // Draw foreground wave
    final frontPath = Path();
    frontPath.moveTo(0, height);
    for (double x = 0; x <= width; x++) {
      final y = baseHeight +
          math.sin((x / width * 2 * math.pi) - (animationValue * 2 * math.pi)) *
              8.0;
      frontPath.lineTo(x, y);
    }
    frontPath.lineTo(width, height);
    frontPath.close();
    canvas.drawPath(frontPath, wavePaintFront);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.waterColor != waterColor;
  }
}

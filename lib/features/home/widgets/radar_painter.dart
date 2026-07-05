import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:waslny_captain/core/theme/app_theme.dart';

/// Custom painter for the radar scanning effect in OnlineWaitingCard.
class RadarPainter extends CustomPainter {
  final double rotation;
  final double pulseScale;

  RadarPainter({
    required this.rotation,
    required this.pulseScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer pulsing ring
    final pulsePaint = Paint()
      ..color = AppColors.success.withValues(alpha: 0.15 * (1 - pulseScale))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * pulseScale, pulsePaint);

    // Second pulse ring
    final scale2 = ((pulseScale + 0.3) % 1.0);
    final pulsePaint2 = Paint()
      ..color = AppColors.success.withValues(alpha: 0.08 * (1 - scale2))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * scale2 * 1.4, pulsePaint2);

    // Circle border
    final borderPaint = Paint()
      ..color = AppColors.success.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius - 2, borderPaint);

    // Scanning arc
    final scanPaint = Paint()
      ..color = AppColors.success.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 2),
      rotation - 0.3, 0.6, true, scanPaint,
    );

    // Scan line
    final linePaint = Paint()
      ..color = AppColors.success.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(
      center,
      Offset(
        center.dx + (radius - 4) * math.cos(rotation),
        center.dy + (radius - 4) * math.sin(rotation),
      ),
      linePaint,
    );

    // Center dot
    final dotPaint = Paint()
      ..color = AppColors.success
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, dotPaint);
  }

  @override
  bool shouldRepaint(RadarPainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.pulseScale != pulseScale;
  }
}

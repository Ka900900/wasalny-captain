import 'package:flutter/material.dart';

/// Paints a **rounded‑rectangle** overlay mask on the camera preview.
///
/// The mask darkens everything outside the target area, leaving a
/// semi‑transparent cut‑out where the user should place their document.
class DocumentOverlayPainter extends CustomPainter {
  DocumentOverlayPainter({
    this.cornerRadius = 12,
    this.borderColor = Colors.white,
    this.maskColor = Colors.black54,
  });

  final double cornerRadius;
  final Color borderColor;
  final Color maskColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Full‑screen overlay
    final paint = Paint()..color = maskColor;
    final fullRect = Offset.zero & size;

    // The cut‑out rectangle ≈ 85 % width, 45 % height, centred
    final cutWidth = size.width * 0.85;
    final cutHeight = size.height * 0.45;
    final cutRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: cutWidth,
        height: cutHeight,
      ),
      Radius.circular(cornerRadius),
    );

    // Draw dark overlay with a transparent hole
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(fullRect),
        Path()..addRRect(cutRect),
      ),
      paint,
    );

    // Draw a bright border around the cut‑out
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(cutRect, borderPaint);

    // Corner brackets
    _drawCornerBrackets(canvas, cutRect, borderColor);
  }

  void _drawCornerBrackets(Canvas canvas, RRect rect, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    const bracketLen = 30.0;
    final r = rect.outerRect;

    // Top‑left
    canvas.drawLine(r.topLeft, Offset(r.left + bracketLen, r.top), paint);
    canvas.drawLine(r.topLeft, Offset(r.left, r.top + bracketLen), paint);

    // Top‑right
    canvas.drawLine(r.topRight, Offset(r.right - bracketLen, r.top), paint);
    canvas.drawLine(r.topRight, Offset(r.right, r.top + bracketLen), paint);

    // Bottom‑left
    canvas.drawLine(r.bottomLeft, Offset(r.left + bracketLen, r.bottom), paint);
    canvas.drawLine(r.bottomLeft, Offset(r.left, r.bottom - bracketLen), paint);

    // Bottom‑right
    canvas.drawLine(
      r.bottomRight,
      Offset(r.right - bracketLen, r.bottom),
      paint,
    );
    canvas.drawLine(
      r.bottomRight,
      Offset(r.right, r.bottom - bracketLen),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant DocumentOverlayPainter oldDelegate) =>
      oldDelegate.borderColor != borderColor ||
      oldDelegate.maskColor != maskColor;
}

/// Paints an **oval** overlay mask for face/selfie capture.
///
/// The cut‑out is an ellipse centred on the screen.  A face must appear
/// inside this oval before capture is enabled.
class FaceOverlayPainter extends CustomPainter {
  FaceOverlayPainter({
    this.borderColor = Colors.white,
    this.maskColor = Colors.black54,
    this.faceDetected = false,
    this.faceDetectedColor = const Color(0xFF2E7D32),
  });

  final Color borderColor;
  final Color maskColor;
  final bool faceDetected;
  final Color faceDetectedColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = maskColor;
    final fullRect = Offset.zero & size;

    // Oval ≈ 70 % width, 50 % height, centred
    final ovalWidth = size.width * 0.70;
    final ovalHeight = size.height * 0.50;
    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: ovalWidth,
      height: ovalHeight,
    );

    // Dark overlay with transparent oval
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(fullRect),
        Path()..addOval(ovalRect),
      ),
      paint,
    );

    // Border — green when face detected, white otherwise
    final borderPaint = Paint()
      ..color = faceDetected ? faceDetectedColor : borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawOval(ovalRect, borderPaint);

    // Guide text hint is drawn by the parent widget
  }

  @override
  bool shouldRepaint(covariant FaceOverlayPainter oldDelegate) =>
      oldDelegate.faceDetected != faceDetected ||
      oldDelegate.borderColor != borderColor;
}

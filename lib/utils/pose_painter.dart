import 'dart:io' show Platform;
import 'package:flutter/material.dart';

class PosePainter extends CustomPainter {
  final List<Map<String, dynamic>> landmarks;
  final bool isFrontCamera;
  final int rotation;
  final Map<String, double> angles;

  PosePainter({
    required this.landmarks,
    required this.isFrontCamera,
    required this.rotation,
    required this.angles,
  });

  Offset _transformPoint(double x, double y, Size size) {
    // ✅ Keep Android behavior EXACTLY as you had it (so you don't break Android)
    if (!Platform.isIOS) {
      
      double px;
      double py;

      switch (rotation) {
        case 90:
          px = y;
          py = x;
          break;

        case 270:
          px = 1 - y;
          py = 1 - x;
          break;

        case 180:
          px = 1 - x;
          py = y;
          break;

        case 0:
        default:
          px = x;
          py = y;
          break;
      }

      // Always flip X because CameraPreview is mirrored internally (your existing assumption)
      px = 1 - px;

      // Mirror ONLY for front camera (net effect: front camera cancels the flip)
      if (isFrontCamera) {
        px = 1 - px;
      }

      return Offset(px * size.width, py * size.height);
    }

    // ✅ iOS fix: correct rotation mapping + mirror rule
    double px;
    double py;
    int rot = rotation;

    switch (rot) {
      case 90:
        // Rotate 90° CW: (x, y) -> (y, 1 - x)
        px = x;
        py = y;
        break;

      case 270:
        // Rotate 270° CW (90° CCW): (x, y) -> (1 - y, x)
        px = 1 - y;
        py = x;
        break;

      case 180:
        // Rotate 180°: (x, y) -> (1 - x, 1 - y)
        px = 1 - x;
        py = 1 - y;
        break;

      case 0:
      default:
        px = x;
        py = y;
        break;
    }

    // On iOS, mirror ONLY for front camera (typical preview behavior)
    //if (isFrontCamera) {
      //px = 1 - px;
    //}

    return Offset(px * size.width, py * size.height);
  }

  void _drawLine(Canvas canvas, Paint paint, Offset a, Offset b) {
    canvas.drawLine(a, b, paint);
  }

  void _drawAngleText(Canvas canvas, Offset position, String text) {
    final textSpan = TextSpan(
      text: text,
      style: const TextStyle(
        color: Colors.red,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );

    final tp = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    tp.layout();
    tp.paint(canvas, position);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty) return;

    final paintLine = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 4;

    final paintDot = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.fill;

    Offset lm(int index) {
      final p = landmarks[index];
      return _transformPoint(
        (p["x"] as num).toDouble(),
        (p["y"] as num).toDouble(),
        size,
      );
    }

    // Draw dots
    for (int i = 0; i < landmarks.length; i++) {
      canvas.drawCircle(lm(i), 5, paintDot);
    }

    void connect(int a, int b) => _drawLine(canvas, paintLine, lm(a), lm(b));

    // shoulders + hips
    connect(11, 12);
    connect(23, 24);

    // left arm
    connect(11, 13);
    connect(13, 15);

    // right arm
    connect(12, 14);
    connect(14, 16);

    // torso
    connect(11, 23);
    connect(12, 24);

    // left leg
    connect(23, 25);
    connect(25, 27);

    // right leg
    connect(24, 26);
    connect(26, 28);

    // ---------- DRAW ANGLES ----------
    if (angles.isEmpty) return;

    void drawAngle(String key, int landmarkIndex) {
      if (!angles.containsKey(key)) return;

      final value = angles[key]!;
      final pos = lm(landmarkIndex);

      _drawAngleText(
        canvas,
        pos.translate(8, -18),
        "${value.toStringAsFixed(0)}°",
      );
    }

    // Elbows
    drawAngle("leftElbow", 13);
    drawAngle("rightElbow", 14);

    // Shoulders
    drawAngle("leftShoulder", 11);
    drawAngle("rightShoulder", 12);

    // Hips
    drawAngle("leftHip", 23);
    drawAngle("rightHip", 24);

    // Knees
    drawAngle("leftKnee", 25);
    drawAngle("rightKnee", 26);

    // Ankles
    drawAngle("leftAnkle", 27);
    drawAngle("rightAnkle", 28);
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return true;
  }
}

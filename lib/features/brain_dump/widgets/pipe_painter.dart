import 'package:flutter/material.dart';

class PipePainter extends CustomPainter {
  final List<Offset> points; // Pairs of [Parent, Child]
  final List<bool> activeStates;
  final Color inactiveColor;
  final Color activeColor;

  PipePainter({
    required this.points,
    required this.activeStates,
    this.inactiveColor = Colors.white24,
    this.activeColor = const Color(0xFF00E5FF),
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final paint = Paint()
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.miter
      ..strokeCap = StrokeCap.square
      ..color = activeColor.withOpacity(0.8);

    // Drawing in pairs [Parent, Child] for better hierarchical control
    for (int i = 0; i < points.length - 1; i += 2) {
      final start = points[i];
      final end = points[i + 1];

      final path = Path();
      path.moveTo(start.dx, start.dy);

      // Compact Hierarchical Routing:
      // Vertical (part way) -> Horizontal -> Vertical
      final midY = (start.dy + end.dy) / 2;

      path.lineTo(start.dx, midY);
      path.lineTo(end.dx, midY);
      path.lineTo(end.dx, end.dy);

      // Main trace
      canvas.drawPath(path, paint);

      // Subtle glow
      final glowPaint = Paint()
        ..color = activeColor.withOpacity(0.2)
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
      canvas.drawPath(path, glowPaint);
    }
  }

  @override
  bool shouldRepaint(PipePainter oldDelegate) => true;
}

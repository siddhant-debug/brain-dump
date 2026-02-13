import 'dart:math';
import 'package:flutter/material.dart';

// ─── Thought data model ────────────────────────────────────────────────────

enum ThoughtCategory { positive, negative, fitness, family }

class Thought {
  const Thought(this.text, this.category);
  final String text;
  final ThoughtCategory category;

  Color get color => switch (category) {
    ThoughtCategory.positive => const Color(0xFF4ADE80), // green
    ThoughtCategory.negative => const Color(0xFFEF4444), // red
    ThoughtCategory.fitness => const Color(0xFF60A5FA), // blue
    ThoughtCategory.family => const Color(0xFFE2E8F0), // white-ish
  };
}

/// Dummy thoughts for the background visual.
const _dummyThoughts = [
  Thought('grateful today', ThoughtCategory.positive),
  Thought('need to rest', ThoughtCategory.negative),
  Thought('morning run ✓', ThoughtCategory.fitness),
  Thought('call mom', ThoughtCategory.family),
  Thought('good progress', ThoughtCategory.positive),
  Thought('feeling tired', ThoughtCategory.negative),
  Thought('5k PR!', ThoughtCategory.fitness),
  Thought('dinner w/ fam', ThoughtCategory.family),
  Thought('love this work', ThoughtCategory.positive),
  Thought('leg day', ThoughtCategory.fitness),
];

// ─── Widget ────────────────────────────────────────────────────────────────

/// A generative "stream of thoughts" background that draws a vertical,
/// branching vine/node graph on the right side of the screen.
///
/// Thought labels glow in category colors along the neural thread.
class NeuralThreadBackground extends StatefulWidget {
  const NeuralThreadBackground({super.key, required this.child});

  final Widget child;

  @override
  State<NeuralThreadBackground> createState() => _NeuralThreadBackgroundState();
}

class _NeuralThreadBackgroundState extends State<NeuralThreadBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _opacityAnim = Tween<double>(
      begin: 0.08,
      end: 0.22,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacityAnim,
      builder: (context, child) {
        return CustomPaint(
          painter: _NeuralThreadPainter(opacity: _opacityAnim.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ─── Painter ───────────────────────────────────────────────────────────────

class _NeuralThreadPainter extends CustomPainter {
  _NeuralThreadPainter({required this.opacity});

  final double opacity;
  static const int _seed = 42;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rand = Random(_seed);

    // Confine to rightmost 150px
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(w - 150, 0, 150, h));

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final nodePaint = Paint()
      ..color = Colors.white.withValues(alpha: opacity * 2.5)
      ..style = PaintingStyle.fill;

    // ── Main trunk ─────────────────────────────────────────────────────
    final trunkX = w - 50.0;
    final path = Path()..moveTo(trunkX, 0);

    const segmentCount = 5;
    final segmentH = h / segmentCount;
    final trunkPoints = <Offset>[Offset(trunkX, 0)];

    for (int i = 0; i < segmentCount; i++) {
      final startY = i * segmentH;
      final endY = (i + 1) * segmentH;
      final drift = (i.isEven ? -1.0 : 1.0) * (20 + rand.nextDouble() * 30);
      final cp1 = Offset(trunkX + drift, startY + segmentH * 0.3);
      final cp2 = Offset(trunkX - drift * 0.6, startY + segmentH * 0.7);
      final end = Offset(trunkX + (rand.nextDouble() - 0.5) * 16, endY);

      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, end.dx, end.dy);
      trunkPoints.add(end);
    }

    canvas.drawPath(path, linePaint);

    // ── Nodes along main trunk ─────────────────────────────────────────
    final nodeCount = _dummyThoughts.length;
    final nodePositions = <Offset>[];

    for (int i = 0; i < nodeCount; i++) {
      // Distribute thoughts evenly along the trunk
      final t = (i + 0.5) / nodeCount;
      final segIdx = (t * segmentCount).floor().clamp(0, segmentCount - 1);
      final localT = (t * segmentCount) - segIdx;
      final start = trunkPoints[segIdx];
      final end = trunkPoints[segIdx + 1];
      final x =
          start.dx +
          (end.dx - start.dx) * localT +
          (rand.nextDouble() - 0.5) * 12;
      final y = start.dy + (end.dy - start.dy) * localT;
      nodePositions.add(Offset(x, y));
    }

    // ── Draw glowing thought nodes + labels ─────────────────────────────
    for (int i = 0; i < nodeCount; i++) {
      final thought = _dummyThoughts[i];
      final pos = nodePositions[i];
      final color = thought.color;

      // Glow circle (larger, blurred)
      final glowPaint = Paint()
        ..color = color.withValues(alpha: opacity * 1.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(pos, 6.0, glowPaint);

      // Solid core node
      final corePaint = Paint()
        ..color = color.withValues(alpha: opacity * 3.5)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 3.0, corePaint);

      // Thought text label
      final textPainter = TextPainter(
        text: TextSpan(
          text: thought.text,
          style: TextStyle(
            color: color.withValues(alpha: opacity * 2.8),
            fontSize: 9,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.3,
            shadows: [
              Shadow(
                color: color.withValues(alpha: opacity * 2.0),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 100);

      // Place label to the left of the node
      final labelOffset = Offset(
        pos.dx - textPainter.width - 12,
        pos.dy - textPainter.height / 2,
      );
      textPainter.paint(canvas, labelOffset);
    }

    // ── Branches ───────────────────────────────────────────────────────
    const branchCount = 4;
    for (int i = 0; i < branchCount; i++) {
      if (nodePositions.isEmpty) break;
      final origin = nodePositions[rand.nextInt(nodePositions.length)];
      final branchLen = 40 + rand.nextDouble() * 50;
      final dirX = (rand.nextBool() ? -1.0 : 1.0) * (0.5 + rand.nextDouble());
      final endPoint = Offset(
        (origin.dx + dirX * branchLen).clamp(w - 150, w.toDouble()),
        origin.dy + branchLen * (0.6 + rand.nextDouble() * 0.4),
      );
      final cp = Offset(
        origin.dx + dirX * branchLen * 0.4,
        origin.dy + branchLen * 0.3,
      );

      final branchPath = Path()
        ..moveTo(origin.dx, origin.dy)
        ..quadraticBezierTo(cp.dx, cp.dy, endPoint.dx, endPoint.dy);

      canvas.drawPath(branchPath, linePaint);
      canvas.drawCircle(endPoint, 2.5, nodePaint);
    }

    // ── Secondary trunk ────────────────────────────────────────────────
    final secondaryPaint = Paint()
      ..color = Colors.white.withValues(alpha: opacity * 0.5)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final secondaryPath = Path()..moveTo(w - 90, 0);
    for (int i = 0; i < segmentCount; i++) {
      final startY = i * segmentH;
      final endY = (i + 1) * segmentH;
      final drift = (i.isOdd ? -1.0 : 1.0) * (15 + rand.nextDouble() * 20);
      secondaryPath.cubicTo(
        w - 90 + drift,
        startY + segmentH * 0.35,
        w - 90 - drift * 0.5,
        startY + segmentH * 0.65,
        w - 90 + (rand.nextDouble() - 0.5) * 10,
        endY,
      );
    }
    canvas.drawPath(secondaryPath, secondaryPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_NeuralThreadPainter old) => old.opacity != opacity;
}

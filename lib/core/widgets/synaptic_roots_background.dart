import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// An organic, upside-down tree (hanging roots / lightning) that grows
/// downward from the top-right corner.
///
/// When [isDockOpen] is false: Roots sway idly.
/// When [isDockOpen] is true: Root tips reach out to connect to the [dockIconPositions].
/*
1 : SynapticRootsBackground is an organic, procedural background widget.
It renders fractal-like roots that sway idly or connect to dock icons.
It uses a CustomPaint for high-performance drawing.
*/
class SynapticRootsBackground extends StatefulWidget {
  const SynapticRootsBackground({
    super.key,
    required this.child,
    required this.isDockOpen,
    required this.dockIconPositions,
    required this.phase,
  });

  /*
  2 : child: The content to be rendered on top of the background.
  isDockOpen: Determines if roots should reach out or stay idle.
  dockIconPositions: The global coordinates of the dock items.
  phase: A 0..1 value from an external pulse animation controller.
  */
  final Widget child;
  final bool isDockOpen;
  final List<Offset> dockIconPositions;
  final double phase;

  @override
  State<SynapticRootsBackground> createState() =>
      _SynapticRootsBackgroundState();
}

class _SynapticRootsBackgroundState extends State<SynapticRootsBackground> {
  @override
  Widget build(BuildContext context) {
    /*
    3 : TweenAnimationBuilder manages the connection transition state (0 = idle, 1 = connected).
    It smooths the morphing of root tips towards their targets.
    */
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
      tween: Tween<double>(begin: 0.0, end: widget.isDockOpen ? 1.0 : 0.0),
      builder: (context, connectionT, child) {
        return CustomPaint(
          painter: _SynapticRootsPainter(
            phase: widget.phase,
            connectionT: connectionT,
            targets: widget.dockIconPositions,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/*
4 : _SynapticRootsPainter handles the actual canvas drawing.
It uses recursive branching to create a "synaptic" or "root-like" structure.
*/
class _SynapticRootsPainter extends CustomPainter {
  _SynapticRootsPainter({
    required this.phase,
    required this.connectionT,
    required this.targets,
  });

  final double phase; // drives the idle sway
  final double connectionT; // drives the reach/morphing to targets
  final List<Offset> targets;

  static const int _seed =
      77; // deterministic seed for consistent tree structure
  static const int _maxDepth = 7; // depth of the fractal recursion

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rand = Random(_seed);

    final baseOpacity = 0.15 + (connectionT * 0.3);

    /*
    5 : The root system starts from the top-right corner and branches downwards.
    */
    _drawRecursiveBranch(
      canvas: canvas,
      rand: rand,
      start: Offset(w - 40, -20),
      angle: pi / 2 + 0.15,
      length: h * 0.28,
      strokeWidth: 3.5,
      opacity: baseOpacity,
      depth: 0,
      targetIndex: 0,
    );
  }

  /*
  6 : _drawRecursiveBranch is the core fractal engine.
  It calculates current segments, applies sway, and handles target morphing at the tips.
  */
  void _drawRecursiveBranch({
    required Canvas canvas,
    required Random rand,
    required Offset start,
    required double angle,
    required double length,
    required double strokeWidth,
    required double opacity,
    required int depth,
    required int targetIndex,
  }) {
    if (depth >= _maxDepth || opacity < 0.01) return;

    // 7 : Calculate natural sway based on global phase and recursion depth
    final sway = sin(phase * pi * 2 + depth * 1.2) * 0.05 * (depth + 1);
    final naturalAngle = angle + sway;

    final naturalEnd = Offset(
      start.dx + cos(naturalAngle) * length,
      start.dy + sin(naturalAngle) * length,
    );

    Offset currentEnd = naturalEnd;

    // 8 : If at a leaf (tip), morph the position towards a dock icon target if connectionT > 0
    bool isTip = depth == _maxDepth - 1;
    int myTargetIdx = -1;

    if (isTip && targets.isNotEmpty) {
      myTargetIdx = targetIndex % targets.length;
    }

    if (isTip && myTargetIdx >= 0 && connectionT > 0.0) {
      final target = targets[myTargetIdx];
      final dx = target.dx - naturalEnd.dx;
      final dy = target.dy - naturalEnd.dy;
      currentEnd = Offset(
        naturalEnd.dx + dx * connectionT,
        naturalEnd.dy + dy * connectionT,
      );
    }

    // 9 : Render the segment using a quadratic bezier path for an organic curve
    final mid = Offset(
      (start.dx + currentEnd.dx) / 2,
      (start.dy + currentEnd.dy) / 2,
    );
    final perpAngle = naturalAngle + pi / 2;
    final bulgeFactor = (1.0 - connectionT * 0.5);
    final bulge = (rand.nextDouble() - 0.5) * length * 0.4 * bulgeFactor;

    final cp = Offset(
      mid.dx + cos(perpAngle) * bulge,
      mid.dy + sin(perpAngle) * bulge,
    );

    final pulse = 0.8 + 0.4 * sin(phase * pi * 2 + depth * 0.7);
    final connectionGlow = connectionT * 0.5;

    final paint = Paint()
      ..color = AppColors.accent.withValues(
        alpha: (opacity * (pulse + connectionGlow)).clamp(0.0, 1.0),
      )
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(cp.dx, cp.dy, currentEnd.dx, currentEnd.dy);

    canvas.drawPath(path, paint);

    // 10 : Draw interactive 'node' glow if fully connected to a target
    if (isTip && connectionT > 0.5 && myTargetIdx >= 0) {
      final nodePaint = Paint()
        ..color = AppColors.accent.withValues(
          alpha: (connectionT * 0.6).clamp(0.0, 1.0),
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(currentEnd, 6.0 * connectionT, nodePaint);

      final corePaint = Paint()
        ..color = AppColors.accent.withValues(alpha: connectionT);
      canvas.drawCircle(currentEnd, 3.0 * connectionT, corePaint);
    }

    // 11 : Split and recurse to create branches
    final splitChance = 0.6 - depth * 0.05;
    final doSplit = rand.nextDouble() < splitChance;
    final childCount = doSplit ? 2 : 1;

    for (int i = 0; i < childCount; i++) {
      final nextTargetIndex = targetIndex + i;

      final spread = doSplit
          ? (i == 0
                ? -(0.25 + rand.nextDouble() * 0.2)
                : (0.2 + rand.nextDouble() * 0.25))
          : (rand.nextDouble() - 0.5) * 0.2;

      _drawRecursiveBranch(
        canvas: canvas,
        rand: rand,
        start: currentEnd,
        angle: naturalAngle + spread,
        length: length * (0.65 + rand.nextDouble() * 0.15),
        strokeWidth: (strokeWidth * 0.7).clamp(0.5, 4.0),
        opacity: opacity * 0.85,
        depth: depth + 1,
        targetIndex: nextTargetIndex,
      );
    }
  }

  @override
  bool shouldRepaint(_SynapticRootsPainter old) =>
      old.phase != phase ||
      old.connectionT != connectionT ||
      old.targets != targets;
}

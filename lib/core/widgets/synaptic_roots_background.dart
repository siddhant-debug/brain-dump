import 'dart:math';
import 'package:flutter/material.dart';

/// An organic, upside-down tree (hanging roots / lightning) that grows
/// downward from the top-right corner.
///
/// When [isDockOpen] is false: Roots sway idly.
/// When [isDockOpen] is true: Root tips reach out to connect to the [dockIconPositions].
class SynapticRootsBackground extends StatefulWidget {
  const SynapticRootsBackground({
    super.key,
    required this.child,
    required this.isDockOpen,
    required this.dockIconPositions,
    required this.phase,
  });

  final Widget child;
  final bool isDockOpen;
  final List<Offset> dockIconPositions;
  final double phase;

  @override
  State<SynapticRootsBackground> createState() =>
      _SynapticRootsBackgroundState();
}

class _SynapticRootsBackgroundState extends State<SynapticRootsBackground> {
  // Removed local AnimationController

  @override
  Widget build(BuildContext context) {
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

// ─── Painter ───────────────────────────────────────────────────────────────

class _SynapticRootsPainter extends CustomPainter {
  _SynapticRootsPainter({
    required this.phase,
    required this.connectionT,
    required this.targets,
  });

  final double phase; // 0..1 pulse animation
  final double connectionT; // 0..1 (0=idle, 1=connected)
  final List<Offset> targets;

  static const int _seed = 77;
  static const int _maxDepth = 7;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rand = Random(_seed);

    // Fade in/out logic:
    // When connecting (T > 0), increased base opacity.
    final baseOpacity = 0.15 + (connectionT * 0.3); // 0.15 -> 0.45

    // Draw the main root system
    // We'll generate branches. The deepest tips will be "assigned" to targets
    // if connectionT > 0.
    _drawRecursiveBranch(
      canvas: canvas,
      rand: rand,
      start: Offset(w - 40, -20),
      angle: pi / 2 + 0.15,
      length: h * 0.28,
      strokeWidth: 3.5,
      opacity: baseOpacity,
      depth: 0,
      targetIndex: 0, // Track which target to connect to
    );
  }

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
    // Stop condition
    if (depth >= _maxDepth || opacity < 0.01) return;

    // ── Calculate "Natural" End Point (Idle State) ──────────────────────
    // Natural sway
    final sway = sin(phase * pi * 2 + depth * 1.2) * 0.05 * (depth + 1);
    final naturalAngle = angle + sway;

    final naturalEnd = Offset(
      start.dx + cos(naturalAngle) * length,
      start.dy + sin(naturalAngle) * length,
    );

    // ── Determine Actual End Point (Morphing) ───────────────────────────
    Offset currentEnd = naturalEnd;

    // If we are deep enough and have a valid target, we morph the tip position
    // ONLY for the specific branches that are destined to be "connectors".
    // We'll strip this down: The first 4 deep branches we find map to targets 0..3.
    // Since this is a fractal, we need a deterministic way to map "leaf X" to "target Y".
    // Simplification: We only morph the VERY tip (last segment) towards the target.

    bool isTip = depth == _maxDepth - 1;
    // We'll use a hacky modulo to assign tips to targets 0-3
    // But since recursion order is deterministic, this works visually.
    int myTargetIdx = -1;

    if (isTip && targets.isNotEmpty) {
      // Pick a target based on the random seed stream state (simulated by passing index or just rand)
      // Actually, passing targetIndex down is cleaner.
      // We assume the tree splits 1->2.
      // Let's just say if we are at a tip, we interpolate to target[targetIndex % total].
      myTargetIdx = targetIndex % targets.length;
    }

    if (isTip && myTargetIdx >= 0 && connectionT > 0.0) {
      final target = targets[myTargetIdx];
      // Interpolate between natural tip and target position
      // Using cubic curve for smooth motion
      final dx = target.dx - naturalEnd.dx;
      final dy = target.dy - naturalEnd.dy;
      currentEnd = Offset(
        naturalEnd.dx + dx * connectionT,
        naturalEnd.dy + dy * connectionT,
      );

      // When fully connected, straighten the curve slightly to look like tension?
      // Or keep it organic. Let's keep organic.
    }

    // ── Draw Segment ───────────────────────────────────────────────────
    // Control point for quadratic bezier
    final mid = Offset(
      (start.dx + currentEnd.dx) / 2,
      (start.dy + currentEnd.dy) / 2,
    );
    final perpAngle = naturalAngle + pi / 2;
    // Reduce bulge as we connect to straigthen out the "reach" slightly
    final bulgeFactor = (1.0 - connectionT * 0.5);
    final bulge = (rand.nextDouble() - 0.5) * length * 0.4 * bulgeFactor;

    final cp = Offset(
      mid.dx + cos(perpAngle) * bulge,
      mid.dy + sin(perpAngle) * bulge,
    );

    // Pulse brightness
    final pulse = 0.8 + 0.4 * sin(phase * pi * 2 + depth * 0.7);
    // If connected, boost brightness significantly to show "energy"
    final connectionGlow = connectionT * 0.5;

    final paint = Paint()
      ..color = Colors.white.withValues(
        alpha: (opacity * (pulse + connectionGlow)).clamp(0.0, 1.0),
      )
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(cp.dx, cp.dy, currentEnd.dx, currentEnd.dy);

    canvas.drawPath(path, paint);

    // ── Interaction: Draw connection node if connected ────────────────
    if (isTip && connectionT > 0.5 && myTargetIdx >= 0) {
      final nodePaint = Paint()
        ..color = Colors.white.withValues(
          alpha: (connectionT * 0.6).clamp(0.0, 1.0),
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(currentEnd, 6.0 * connectionT, nodePaint);

      final corePaint = Paint()
        ..color = Colors.white.withValues(alpha: connectionT);
      canvas.drawCircle(currentEnd, 3.0 * connectionT, corePaint);
    }

    // ── Recursion ──────────────────────────────────────────────────────
    final splitChance = 0.6 - depth * 0.05;
    final doSplit = rand.nextDouble() < splitChance;
    final childCount = doSplit ? 2 : 1;

    for (int i = 0; i < childCount; i++) {
      // Pass a modified target index to distribute targets among children
      // e.g. Left child gets target, right gets target+1
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
        angle:
            naturalAngle +
            spread, // Angle relative to *natural* flow, not the distorted one
        length: length * (0.65 + rand.nextDouble() * 0.15),
        strokeWidth: (strokeWidth * 0.7).clamp(0.5, 4.0),
        opacity: opacity * 0.85, // slower fade
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

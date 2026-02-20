import 'package:flutter/material.dart';
import '../models/pipeline_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

/// Row height per node — taller to fit dot + text below it.
const _kRowHeight = 90.0;

/// Diameter of the circle node on the track.
const _kDotSize = 16.0;

/// Lane labels.
const _kLaneLabels = ['WORK', 'HEALTH', 'PERSONAL'];

/// Lane icons.
const _kLaneIcons = [
  Icons.work_rounded,
  Icons.monitor_heart_rounded,
  Icons.person_outline_rounded,
];

// ─────────────────────────────────────────────────────────────────────────────
// PIPELINE GRAPH WIDGET
// ─────────────────────────────────────────────────────────────────────────────

/// Git-graph style with thoughts shown BELOW each dot in the lane's column:
///
/// ```
///    💼         🏃        🌱
///   WORK      HEALTH   PERSONAL
///    │          │          │
///    ●          │          │
///  "Sprint      │          │
///   planning"   │          │
///    │          ●          │
///    │       "Morning      │
///    │        gym"         │
///    │          │          ●
///    │          │       "Birthday
///    │          │        plans"
/// ```
class PipelineGraphWidget extends StatelessWidget {
  final List<PipelineNode> nodes;

  const PipelineGraphWidget({super.key, required this.nodes});

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No pipeline data yet.\nKeep writing notes!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 14, height: 1.6),
          ),
        ),
      );
    }

    // Newest first.
    final display = List<PipelineNode>.from(nodes.reversed);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        // 3 tracks spread evenly across the full width.
        // Each lane gets ~1/3 of the space, centered within its third.
        final trackX = [
          width * 0.17, // WORK
          width * 0.50, // HEALTH (center)
          width * 0.83, // PERSONAL
        ];

        // Width available for text in each column.
        final columnWidth = width / 3;

        return Column(
          children: [
            // ── Fork Header ──────────────────────────────────────────────
            _ForkHeader(trackX: trackX, totalWidth: width),
            const SizedBox(height: 2),

            // ── Scrollable Timeline ──────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 32),
                child: SizedBox(
                  height: display.length * _kRowHeight,
                  child: CustomPaint(
                    painter: _GitGraphPainter(nodes: display, trackX: trackX),
                    child: Stack(
                      children: List.generate(display.length, (i) {
                        final node = display[i];
                        return Positioned(
                          top: i * _kRowHeight,
                          left: 0,
                          right: 0,
                          height: _kRowHeight,
                          child: _NodeRow(
                            node: node,
                            trackX: trackX[node.lane],
                            columnWidth: columnWidth,
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FORK HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _ForkHeader extends StatelessWidget {
  final List<double> trackX;
  final double totalWidth;

  const _ForkHeader({required this.trackX, required this.totalWidth});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: totalWidth,
      height: 48,
      child: Stack(
        children: [
          // Fork lines (painted)
          Positioned.fill(
            child: CustomPaint(
              painter: _ForkPainter(trackX: trackX, totalWidth: totalWidth),
            ),
          ),
          // Lane icons + labels at the bottom
          ...List.generate(3, (lane) {
            final color = PipelineNode.laneColor(lane);
            return Positioned(
              left: trackX[lane] - 28,
              bottom: 0,
              width: 56,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Icon(_kLaneIcons[lane], size: 11, color: color),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _kLaneLabels[lane],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.8),
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Paints: horizontal bar → 3 coloured drops
class _ForkPainter extends CustomPainter {
  final List<double> trackX;
  final double totalWidth;

  const _ForkPainter({required this.trackX, required this.totalWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final barPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const barY = 8.0;
    const dropEnd = 22.0;

    // Horizontal bar
    canvas.drawLine(Offset(trackX[0], barY), Offset(trackX[2], barY), barPaint);

    // 3 coloured drops
    for (int lane = 0; lane < 3; lane++) {
      final paint = Paint()
        ..color = PipelineNode.laneColor(lane).withValues(alpha: 0.35)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(trackX[lane], barY),
        Offset(trackX[lane], dropEnd),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ForkPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// NODE ROW — dot at top, content below, centered on the lane column
// ─────────────────────────────────────────────────────────────────────────────

class _NodeRow extends StatelessWidget {
  final PipelineNode node;
  final double trackX; // X position of this lane's vertical line
  final double columnWidth; // width available for text

  const _NodeRow({
    required this.node,
    required this.trackX,
    required this.columnWidth,
  });

  @override
  Widget build(BuildContext context) {
    final color = node.color;
    final time =
        '${node.timestamp.hour.toString().padLeft(2, '0')}:'
        '${node.timestamp.minute.toString().padLeft(2, '0')}';

    // Text block sits centered on the track, constrained by column width.
    final textLeft = trackX - (columnWidth * 0.45);
    final textWidth = columnWidth * 0.9;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Dot on the track (near the top of the row) ───────────────────
        Positioned(
          left: trackX - (_kDotSize / 2),
          top: 6,
          child: Container(
            width: _kDotSize,
            height: _kDotSize,
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0D),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2.0),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6),
              ],
            ),
          ),
        ),

        // ── Content below the dot, centered on the lane ──────────────────
        Positioned(
          left: textLeft.clamp(4.0, double.infinity),
          top: 6 + _kDotSize + 4, // below dot + small gap
          width: textWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Topic badge + time
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      node.topic.toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    time,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 9,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              // Note content
              Text(
                node.content,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GIT GRAPH PAINTER — continuous vertical lines + cross-lane beziers
// ─────────────────────────────────────────────────────────────────────────────

class _GitGraphPainter extends CustomPainter {
  final List<PipelineNode> nodes;
  final List<double> trackX;

  const _GitGraphPainter({required this.nodes, required this.trackX});

  @override
  void paint(Canvas canvas, Size size) {
    // ── 1. Continuous vertical lines per lane ────────────────────────────
    final lastRowPerLane = <int, int>{};
    for (int i = 0; i < nodes.length; i++) {
      lastRowPerLane[nodes[i].lane] = i;
    }

    for (int lane = 0; lane < 3; lane++) {
      if (!lastRowPerLane.containsKey(lane)) continue;

      final x = trackX[lane];
      // Line extends to the dot position (top of row + offset)
      final bottomY =
          (lastRowPerLane[lane]! * _kRowHeight) + 6 + (_kDotSize / 2);

      final paint = Paint()
        ..color = PipelineNode.laneColor(lane).withValues(alpha: 0.18)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(x, 0), Offset(x, bottomY), paint);
    }

    // ── 2. Cross-lane bezier connections ──────────────────────────────────
    final nodeIndex = {for (var i = 0; i < nodes.length; i++) nodes[i].id: i};
    final connPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < nodes.length; i++) {
      final child = nodes[i];
      for (final parentId in child.parentIds) {
        final pi = nodeIndex[parentId];
        if (pi == null || nodes[pi].lane == child.lane) continue;

        final parent = nodes[pi];
        // Dot center = row*height + 6 (top offset) + dotSize/2
        final childCenter = Offset(
          trackX[child.lane],
          i * _kRowHeight + 6 + _kDotSize / 2,
        );
        final parentCenter = Offset(
          trackX[parent.lane],
          pi * _kRowHeight + 6 + _kDotSize / 2,
        );

        connPaint.color = child.color.withValues(alpha: 0.15);

        final midY = (childCenter.dy + parentCenter.dy) / 2;
        final path = Path()
          ..moveTo(childCenter.dx, childCenter.dy)
          ..cubicTo(
            childCenter.dx,
            midY,
            parentCenter.dx,
            midY,
            parentCenter.dx,
            parentCenter.dy,
          );
        canvas.drawPath(path, connPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GitGraphPainter old) => old.nodes != nodes;
}

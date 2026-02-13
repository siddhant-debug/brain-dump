import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../vault/services/file_service.dart';
import '../../vault/presentation/file_vault_screen.dart';

class InteractiveNeuralTree extends ConsumerWidget {
  final double phase;
  const InteractiveNeuralTree({super.key, required this.phase});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filesState = ref.watch(filesProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return filesState.when(
          data: (files) {
            // Replicate the deterministic random tree logic to get node positions
            final nodes = _calculateNodePositions(w, h, files.length, phase);

            return Stack(
              children: List.generate(nodes.length, (index) {
                final node = nodes[index];
                final file = files[index];

                return Positioned(
                  left: node.dx - 6,
                  top: node.dy - 6,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => FileViewer(
                            filename: file['filename'],
                            type: file['file_type'],
                            content: null,
                          ),
                        ),
                      );
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // The Node Glow
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blueAccent.withOpacity(0.8),
                                blurRadius: 15,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        // The Tag/Label
                        Positioned(
                          left: -50, // Center roughly
                          top: 18,
                          child: Container(
                            width: 100,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Text(
                              file['filename'],
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
    );
  }

  List<Offset> _calculateNodePositions(
    double w,
    double h,
    int count,
    double phase,
  ) {
    final rand = Random(77); // Same seed as painter
    final positions = <Offset>[];

    // Recursive calculation similar to the painter
    _recursiveCalculate(
      rand: rand,
      start: Offset(w - 40, -20),
      angle: pi / 2 + 0.15,
      length: h * 0.28,
      depth: 0,
      positions: positions,
      maxNodes: count,
      phase: phase,
    );

    return positions;
  }

  void _recursiveCalculate({
    required Random rand,
    required Offset start,
    required double angle,
    required double length,
    required int depth,
    required List<Offset> positions,
    required int maxNodes,
    required double phase,
  }) {
    if (positions.length >= maxNodes) return;

    // Apply the same sway logic as the painter
    final sway = sin(phase * pi * 2 + depth * 1.2) * 0.05 * (depth + 1);
    final naturalAngle = angle + sway;

    final end = Offset(
      start.dx + cos(naturalAngle) * length,
      start.dy + sin(naturalAngle) * length,
    );

    // Pick nodes in the "middle" (depth 3 or 4)
    if (depth == 3 || depth == 4) {
      if (positions.length < maxNodes && rand.nextDouble() > 0.3) {
        positions.add(end);
      }
    }

    if (depth >= 6) return;

    // Recursion
    final splitChance = 0.6 - depth * 0.05;
    final doSplit = rand.nextDouble() < splitChance;
    final childCount = doSplit ? 2 : 1;

    for (int i = 0; i < childCount; i++) {
      final spread = doSplit
          ? (i == 0 ? -0.3 : 0.3)
          : (rand.nextDouble() - 0.5) * 0.2;

      _recursiveCalculate(
        rand: rand,
        start: end,
        angle: angle + spread,
        length: length * 0.75,
        depth: depth + 1,
        positions: positions,
        maxNodes: maxNodes,
        phase: phase,
      );
    }
  }
}

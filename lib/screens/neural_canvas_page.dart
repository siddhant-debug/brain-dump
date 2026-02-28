import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import '../features/brain_dump/widgets/pipe_painter.dart';
import '../features/vault/services/file_service.dart';
import '../features/vault/presentation/file_vault_screen.dart';
import '../core/theme/app_theme.dart';

class NeuralCanvasPage extends ConsumerStatefulWidget {
  const NeuralCanvasPage({super.key});

  @override
  ConsumerState<NeuralCanvasPage> createState() => _NeuralCanvasPageState();
}

class _NeuralCanvasPageState extends ConsumerState<NeuralCanvasPage> {
  final TransformationController _transformationController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    _centerView();
  }

  void _centerView() {
    const canvasSize = 4000.0;
    final zoom = 1.0; // Dynamic zoom for compact view
    final centerX = canvasSize / 2;
    final topY = 150.0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = MediaQuery.of(context).size;
      final tx = (size.width / 2) - (centerX * zoom);
      final ty = 100.0 - (topY * zoom);

      _transformationController.value = Matrix4.identity()
        ..translateByDouble(tx, ty, 0, 0)
        ..scaleByDouble(zoom, zoom, 1, 1);
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filesState = ref.watch(filesProvider);

    return filesState.when(
      data: (files) {
        const canvasSize = 4000.0;
        final centerX = canvasSize / 2;
        final rootPos = Offset(centerX, 150.0);

        // Algorithm: Compact Hierarchical Tree
        // Level 1: Hub
        // Level 2: All nodes tightly packed in rows if many, or one dense row.
        const nodeWidth = 160.0;
        const siblingSpacing = 20.0;
        const verticalSpacing = 60.0;

        final nodePositions = <Offset>[rootPos];
        final pipePoints = <Offset>[];
        final pipeActivity = <bool>[];

        // Simple Level-based packing
        // We'll calculate a centered width for the row of nodes
        final totalRowWidth =
            (files.length * nodeWidth) + ((files.length - 1) * siblingSpacing);
        final startX = centerX - (totalRowWidth / 2);

        for (int i = 0; i < files.length; i++) {
          final childPos = Offset(
            startX + (i * (nodeWidth + siblingSpacing)) + (nodeWidth / 2),
            rootPos.dy + verticalSpacing + 36.0, // 36 is node height
          );

          nodePositions.add(childPos);

          // Connect from bottom of hub to top of chip
          pipePoints.add(Offset(rootPos.dx, rootPos.dy + 15));
          pipePoints.add(Offset(childPos.dx, childPos.dy - 18));
          pipeActivity.add(true);
        }

        return InteractiveViewer(
          transformationController: _transformationController,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(double.infinity),
          minScale: 0.1,
          maxScale: 2.0,
          child: Container(
            width: canvasSize,
            height: canvasSize,
            color: Colors.transparent,
            child: Stack(
              children: [
                // Compact Traces
                CustomPaint(
                  size: const Size(canvasSize, canvasSize),
                  painter: PipePainter(
                    points: pipePoints,
                    activeStates: pipeActivity,
                    activeColor: AppColors.accent, // Trace color
                  ),
                ),

                // Micro-Chip Nodes
                ...List.generate(files.length, (index) {
                  final file = files[index];
                  final pos = nodePositions[index + 1];

                  return Positioned(
                    left: pos.dx - (nodeWidth / 2),
                    top: pos.dy - 18, // Half height (36/2)
                    child: _MicroChip(
                      file: file,
                      onTap: () async {
                        try {
                          final content = await ref
                              .read(fileServiceProvider)
                              .getFileContent(file['id']);
                          if (context.mounted) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => FileViewer(
                                  filename: file['filename'],
                                  type: file['file_type'],
                                  content: content,
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Load failed: $e')),
                            );
                          }
                        }
                      },
                    ),
                  );
                }),

                // Entry Hub
                Positioned(
                  left: rootPos.dx - 15,
                  top: rootPos.dy - 15,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.2),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.memory,
                      color: AppColors.accent,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

class _MicroChip extends StatelessWidget {
  final Map<String, dynamic> file;
  final VoidCallback onTap;

  const _MicroChip({required this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: 160,
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.5),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  file['file_type'] == 'pdf'
                      ? Icons.picture_as_pdf
                      : Icons.description,
                  size: 14,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    file['filename'],
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

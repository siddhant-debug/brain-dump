import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/analytics_service.dart';
import 'pipeline_graph_widget.dart';

/// Opens the pipeline sheet as a draggable bottom sheet.
/// Call this function from anywhere in the analytics screen.
void showPipelineSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _PipelineSheetContent(),
  );
}

// ── Sheet content (has its own ProviderScope consumer) ────────────────────────

class _PipelineSheetContent extends ConsumerWidget {
  const _PipelineSheetContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pipelineState = ref.watch(pipelineProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D0D0D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // ── Handle ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_tree_rounded,
                    color: Color(0xFF2979FF),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Thought Pipeline',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white10, height: 1),

            // ── Body ────────────────────────────────────────────────────────
            Expanded(
              child: pipelineState.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white24,
                    strokeWidth: 1.5,
                  ),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.white24,
                          size: 40,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Could not load pipeline',
                          style: TextStyle(color: Colors.white54, fontSize: 15),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          e.toString().replaceFirst('Exception: ', ''),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white24,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextButton.icon(
                          onPressed: () => ref.invalidate(pipelineProvider),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Retry'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (data) => PipelineGraphWidget(nodes: data.nodes),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/analytics_service.dart';
import '../widgets/full_page_header.dart';
import '../../widgets/pipeline_graph_widget.dart';

class PipelinePage extends ConsumerWidget {
  const PipelinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pipelineState = ref.watch(pipelineProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
      child: Column(
        children: [
          const FullPageHeader(
            icon: Icons.account_tree_rounded,
            title: 'Knowledge Pipeline',
            accent: Color(0xFF2979FF),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 500,
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
    );
  }
}

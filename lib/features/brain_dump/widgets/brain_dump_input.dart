import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/brain_dump_provider.dart';

class BrainDumpInput extends ConsumerWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final String? userName;

  const BrainDumpInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    this.userName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(brainDumpProvider);
    
    final hint = state.isChatMode
        ? 'Ask anything...'
        : (userName != null
            ? 'welcome back ${userName!.toLowerCase()}, Drop a thought…'
            : 'Drop a thought…');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 0.5)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => ref.read(brainDumpProvider.notifier).toggleMode(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                state.isChatMode ? 'CHAT' : 'JOURNAL',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              maxLines: null,
              onSubmitted: onSubmitted,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_upward, color: Colors.white),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                onSubmitted(controller.text);
              }
            },
          ),
        ],
      ),
    );
  }
}

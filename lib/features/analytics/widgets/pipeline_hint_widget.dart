import 'package:flutter/material.dart';

/// A permanent left-edge tab that pulses gently to hint at the pipeline.
/// Tap it to open the pipeline sheet.
class PipelineHintWidget extends StatefulWidget {
  final VoidCallback onTap;

  const PipelineHintWidget({super.key, required this.onTap});

  @override
  State<PipelineHintWidget> createState() => _PipelineHintWidgetState();
}

class _PipelineHintWidgetState extends State<PipelineHintWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);

    _opacity = Tween<double>(
      begin: 0.35,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      bottom: 160,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _opacity,
          builder: (_, child) => Opacity(opacity: _opacity.value, child: child),
          child: _buildTab(),
        ),
      ),
    );
  }

  Widget _buildTab() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 14, 6, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2979FF).withValues(alpha: 0.18),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.account_tree_rounded,
            color: Color(0xFF2979FF),
            size: 16,
          ),
          const SizedBox(height: 6),
          RotatedBox(
            quarterTurns: 1,
            child: Text(
              'Pipeline',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 10,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

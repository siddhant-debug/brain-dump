import 'package:flutter/material.dart';

class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration pauseDuration;
  final double scrollSpeed; // pixels per 40ms approx

  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.pauseDuration = const Duration(seconds: 1),
    this.scrollSpeed = 40,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  void _startScrolling() async {
    while (mounted) {
      await Future.delayed(widget.pauseDuration);
      if (!mounted || !_scrollController.hasClients) return;

      final max = _scrollController.position.maxScrollExtent;
      if (max <= 0) continue;

      await _scrollController.animateTo(
        max,
        duration: Duration(milliseconds: (max * widget.scrollSpeed).toInt()),
        curve: Curves.linear,
      );

      await Future.delayed(widget.pauseDuration);
      if (!mounted) return;

      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(widget.text, style: widget.style, maxLines: 1),
    );
  }
}

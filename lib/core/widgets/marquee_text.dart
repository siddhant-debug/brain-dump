import 'package:flutter/material.dart';

/*
1 : MarqueeText is a horizontal scrolling utility for long strings.
It uses an infinite while loop in its initState to animate the scroll position.
*/
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
  /*
  2 : _scrollController is used to programmatically move the scroll position.
  */
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // 3 : Start the scrolling loop after the first frame is rendered.
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  /*
  4 : _startScrolling manages the animation loop:
  - Wait for pauseDuration.
  - Calculate max scroll extent.
  - Animate to the end at a constant speed.
  - Wait again.
  - Snap back to start and repeat.
  */
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

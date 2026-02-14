import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../music/models/now_playing_info.dart';
import '../models/dock_item_model.dart';
import '../../../core/widgets/marquee_text.dart';

/*
1 : MagnifiedDock is an interactive sidebar that expands when hovered or dragged.
It uses 'Fish-eye' magnification logic where icons grow based on their distance 
from the user's cursor or touch point.
*/
class MagnifiedDock extends StatefulWidget {
  final Map<String, NowPlayingInfo?> activeApps;
  final List<GlobalKey> iconKeys;
  final bool isOpen;
  final VoidCallback onToggle;
  final List<DockItemModel> items;

  const MagnifiedDock({
    super.key,
    required this.activeApps,
    required this.iconKeys,
    required this.isOpen,
    required this.onToggle,
    this.items = defaultDockItems,
  });

  @override
  State<MagnifiedDock> createState() => _MagnifiedDockState();
}

class _MagnifiedDockState extends State<MagnifiedDock> {
  /*
  2 : _hoverYNotifier tracks the vertical position of the cursor/touch.
  It is used to calculate the focal point of the magnification effect.
  */
  final ValueNotifier<double?> _hoverYNotifier = ValueNotifier<double?>(null);

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      right: widget.isOpen ? 0.0 : -40.0,
      top: 0,
      bottom: 0,
      child: Center(
        child: RepaintBoundary(
          child: GestureDetector(
            onTap: widget.onToggle,
            onVerticalDragUpdate: widget.isOpen
                ? (details) => _hoverYNotifier.value = details.localPosition.dy
                : null,
            onVerticalDragEnd: (_) => _hoverYNotifier.value = null,
            child: MouseRegion(
              onHover: widget.isOpen
                  ? (event) => _hoverYNotifier.value = event.localPosition.dy
                  : null,
              onExit: (_) => _hoverYNotifier.value = null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutBack,
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E).withValues(alpha: 0.4),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(35),
                    bottomLeft: Radius.circular(35),
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(-5, 0),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(35),
                    bottomLeft: Radius.circular(35),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(widget.items.length, (index) {
                        /*
                        3 : ValueListenableBuilder ensures that only the dock items 
                        rebuild when the hover position changes, optimizing performance.
                        */
                        return ValueListenableBuilder<double?>(
                          valueListenable: _hoverYNotifier,
                          builder: (context, hoverY, child) {
                            return _MagnifiedDockItem(
                              item: widget.items[index],
                              hoverY: hoverY,
                              isOpen: widget.isOpen,
                              isActive:
                                  widget.activeApps[widget.items[index].id] !=
                                  null,
                              info: widget.activeApps[widget.items[index].id],
                              index: index,
                              iconKey: widget.iconKeys[index],
                              onToggle: widget.onToggle,
                            );
                          },
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MagnifiedDockItem extends StatelessWidget {
  final DockItemModel item;
  final double? hoverY;
  final bool isOpen;
  final bool isActive;
  final NowPlayingInfo? info;
  final int index;
  final GlobalKey iconKey;
  final VoidCallback onToggle;

  const _MagnifiedDockItem({
    required this.item,
    required this.hoverY,
    required this.isOpen,
    required this.isActive,
    required this.info,
    required this.index,
    required this.iconKey,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    const double baseIconSize = 50.0;
    const double maxScale = 1.6;
    const double magnificationRadius = 120.0;
    const double pillThreshold = 1.35;

    final double itemCenterY = 47.0 + (index * 62.0);

    double scale = 1.0;
    if (isOpen && hoverY != null) {
      final double distance = (hoverY! - itemCenterY).abs();
      if (distance < magnificationRadius) {
        scale = 1.0 + (maxScale - 1.0) * pow(e, -pow(distance / 50, 2));
      }
    }

    final bool isPillExpanded = isOpen && isActive && scale > pillThreshold;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Stack(
        alignment: Alignment.centerRight,
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            width: isPillExpanded ? 240 : baseIconSize,
            constraints: BoxConstraints(
              minHeight: baseIconSize * (isOpen ? scale : 1.0),
              maxHeight: 120,
            ),
            decoration: BoxDecoration(
              color: isPillExpanded
                  ? item.color.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isPillExpanded
                    ? item.color.withValues(alpha: 0.3)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: isPillExpanded
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: SizedBox(
                      width: 240,
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          const Icon(
                            Icons.music_note_rounded,
                            size: 14,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: MarqueeText(
                              text: "${info!.artist} — ${info!.title}",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 50),
                        ],
                      ),
                    ),
                  )
                : null,
          ),

          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                if (!isOpen) {
                  onToggle();
                } else {
                  debugPrint("Tapped ${item.id}");
                }
              },
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),
          ),

          AnimatedScale(
            scale: isOpen ? scale : 1.0,
            duration: const Duration(milliseconds: 150),
            child: SizedBox(
              key: iconKey,
              width: baseIconSize,
              height: baseIconSize,
              child: Center(
                child: FaIcon(
                  item.icon,
                  color: isActive
                      ? item.color
                      : Colors.white.withValues(alpha: 0.6),
                  size: 24,
                ),
              ),
            ),
          ),

          if (isActive)
            Positioned(
              bottom: 2,
              right: 22,
              child: AnimatedScale(
                scale: isOpen ? scale : 1.0,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_provider.dart';

class OmniBar extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final VoidCallback onSubmitted;
  final String hintText;
  final bool showMic;
  final bool autoTriggerMic;
  final bool isProcessing;
  final Widget? leading;

  const OmniBar({
    super.key,
    required this.controller,
    this.focusNode,
    required this.onSubmitted,
    this.hintText = "ask anything...",
    this.showMic = false,
    this.autoTriggerMic = false,
    this.isProcessing = false,
    this.leading,
  });

  @override
  ConsumerState<OmniBar> createState() => _OmniBarState();
}

class _OmniBarState extends ConsumerState<OmniBar> {
  static const _speechChannel = MethodChannel('com.braindump.speech');
  bool _isEmpty = true;

  @override
  void initState() {
    super.initState();
    _isEmpty = widget.controller.text.trim().isEmpty;
    widget.controller.addListener(_onTextChanged);

    // IMPROVEMENT: Area 1 — Siri Shortcut Integration
    if (widget.autoTriggerMic) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _startVoiceInput(context, ref.read(themeProvider).colors);
        }
      });
    }
  }

  @override
  void didUpdateWidget(OmniBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
      _isEmpty = widget.controller.text.trim().isEmpty;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final isEmpty = widget.controller.text.trim().isEmpty;
    if (_isEmpty != isEmpty) {
      setState(() => _isEmpty = isEmpty);
    }
  }

  Future<void> _startVoiceInput(BuildContext context, CircadianColors colors) async {
    try {
      // IMPROVEMENT: Area 5c — Real Permission Trigger
      final bool granted = await _speechChannel.invokeMethod('requestPermissions');
      
      if (!granted && context.mounted) {
        // Only show mock/instruction dialog if permissions are denied
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.large),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Microphone Access",
                  style: AppTextStyles.h2(colors.text),
                ),
                const SizedBox(height: 12),
                Text(
                  "To use voice input, please enable microphone and speech recognition access in your iOS Settings.",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(colors.textDim),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Got it",
                    style: AppTextStyles.label(colors.accent),
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (granted) {
          debugPrint("[OmniBar] Speech permissions granted. Ready for recording logic.");
          // NOTE: Real recording logic would follow here.
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to request speech permissions: ${e.message}");
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final colors = themeState.colors;

    return GestureDetector(
      onTap: () => widget.focusNode?.requestFocus(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: widget.isProcessing ? 0.6 : 1.0),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.surfaceBorder.withValues(alpha: widget.isProcessing ? 0.5 : 1.0),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  if (widget.leading != null) ...[
                    Opacity(
                      opacity: widget.isProcessing ? 0.5 : 1.0,
                      child: widget.leading!,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      enabled: !widget.isProcessing,
                      onSubmitted: (_) => widget.onSubmitted(),
                      style: AppTextStyles.body(
                        widget.isProcessing ? colors.textDim : colors.text,
                      ),
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        hintStyle: AppTextStyles.body(
                          colors.textDim.withValues(alpha: 0.5),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (widget.isProcessing)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                      ),
                    )
                  else
                    // IMPROVEMENT: Area 2h — OmniBar Send Button State
                    GestureDetector(
                      onTap: () {
                         if (widget.showMic && _isEmpty) {
                           _startVoiceInput(context, colors);
                         } else if (!_isEmpty) {
                           widget.onSubmitted();
                         }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _isEmpty && !widget.showMic ? colors.surfaceLow : colors.accentBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isEmpty && !widget.showMic ? colors.surfaceBorder : colors.accentBorder,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            widget.showMic && _isEmpty
                                ? Icons.mic_rounded
                                : Icons.arrow_upward_rounded,
                            size: 18,
                            color: _isEmpty && !widget.showMic ? colors.textDim : colors.accent,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

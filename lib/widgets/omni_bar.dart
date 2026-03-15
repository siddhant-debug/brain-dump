import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_provider.dart';

class OmniBar extends ConsumerWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final VoidCallback onSubmitted;
  final String hintText;
  final bool showMic;
  final bool isProcessing;
  final Widget? leading;

  const OmniBar({
    super.key,
    required this.controller,
    this.focusNode,
    required this.onSubmitted,
    this.hintText = "ask anything...",
    this.showMic = false,
    this.isProcessing = false,
    this.leading,
  });

  void _handleMicTap(BuildContext context, CircadianColors colors) {
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
              "To use voice input, please enable microphone access in your iOS Settings.",
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
  }


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final colors = themeState.colors;

    return GestureDetector(
      onTap: () => focusNode?.requestFocus(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: isProcessing ? 0.6 : 1.0),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.surfaceBorder.withValues(alpha: isProcessing ? 0.5 : 1.0),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  if (leading != null) ...[
                    Opacity(
                      opacity: isProcessing ? 0.5 : 1.0,
                      child: leading!,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      enabled: !isProcessing,
                      onSubmitted: (_) => onSubmitted(),
                      style: AppTextStyles.body(
                        isProcessing ? colors.textDim : colors.text,
                      ),
                      decoration: InputDecoration(
                        hintText: hintText,
                        hintStyle: AppTextStyles.body(
                          colors.textDim.withValues(alpha: 0.5),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isProcessing)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: showMic
                          ? () => _handleMicTap(context, colors)
                          : onSubmitted,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: colors.accentBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colors.accentBorder,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            showMic
                                ? Icons.mic_rounded
                                : Icons.arrow_upward_rounded,
                            size: 18,
                            color: colors.accent,
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

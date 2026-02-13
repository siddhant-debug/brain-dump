import 'package:flutter/material.dart';

/// A subtle, ghost-style icon button for the minimalist UI.
class MinimalIconButton extends StatelessWidget {
  const MinimalIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isLoading = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isLoading ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white24,
                    ),
                  )
                : Icon(
                    icon,
                    size: 20,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
          ),
        ),
      ),
    );
  }
}

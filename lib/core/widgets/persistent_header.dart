import 'package:flutter/material.dart';

class PersistentHeader extends StatelessWidget {
  final String title;
  final List<Widget>? actions;

  const PersistentHeader({super.key, required this.title, this.actions});

  @override
  Widget build(BuildContext context) {
    // Rely on SafeArea from parent instead of hardcoding 60px top padding
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (actions != null)
            Row(mainAxisSize: MainAxisSize.min, children: actions!),
        ],
      ),
    );
  }
}

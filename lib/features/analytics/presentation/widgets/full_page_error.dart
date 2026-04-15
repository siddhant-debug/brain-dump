import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class FullPageError extends StatelessWidget {
  final String message;
  const FullPageError({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 40,
          ),
          SizedBox(height: 16),
          Text(message, style: TextStyle(color: AppColors.error)),
        ],
      ),
    );
  }
}

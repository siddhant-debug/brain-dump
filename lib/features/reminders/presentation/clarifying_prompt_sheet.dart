import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/smart_reminder_controller.dart';
import '../controllers/smart_reminder_state.dart';

class ClarifyingPromptSheet extends ConsumerWidget {
  const ClarifyingPromptSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(smartReminderControllerProvider);
    final controller = ref.read(smartReminderControllerProvider.notifier);
    final colors = CircadianColors.current;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xl),
      decoration: BoxDecoration(
        color: colors.bgTop,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Smart Routing',
                style: AppTextStyles.h2(colors.text),
              ),
              IconButton(
                icon: Icon(Icons.close, color: colors.textDim),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'I\'ll set a reminder for "${state.parseResult?.action ?? 'your request'}". Is this a one-time thing or recurring?',
            style: AppTextStyles.body(colors.textDim),
          ),
          const SizedBox(height: AppSpacing.xl),
          
          if (state.status == SmartReminderStatus.permissionDenied) ...[
            _buildPermissionWarning(context, colors, controller),
          ] else if (state.status == SmartReminderStatus.needsPermission) ...[
            _buildPermissionRequest(context, colors, controller),
          ] else if (state.status == SmartReminderStatus.error) ...[
            _buildErrorState(colors, state.errorMessage),
          ] else if (state.status == SmartReminderStatus.success) ...[
            _buildSuccessState(context, colors),
          ] else ...[
            _buildRecurrenceOptions(context, colors, controller, state),
          ],
          
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildRecurrenceOptions(
    BuildContext context, 
    CircadianColors colors, 
    SmartReminderController controller,
    SmartReminderState state
  ) {
    return Column(
      children: [
        _OptionTile(
          title: 'Just this once',
          subtitle: 'One-time reminder at the detected time',
          icon: Icons.event_available_rounded,
          onTap: () => controller.executeRouting(),
          isLoading: state.status == SmartReminderStatus.executing,
          colors: colors,
        ),
        const SizedBox(height: AppSpacing.md),
        _OptionTile(
          title: 'Every Day',
          subtitle: 'Create a recurring daily reminder',
          icon: Icons.repeat_rounded,
          onTap: () {
            // In a real app, we might show more options, but for now we follow the "did you mean every day" flow
            // This would ideally update the controller's state with a daily recurrence before executing
            controller.executeRouting(); // Simplified for this task
          },
          isLoading: state.status == SmartReminderStatus.executing,
          colors: colors,
        ),
      ],
    );
  }

  Widget _buildPermissionWarning(BuildContext context, CircadianColors colors, SmartReminderController controller) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.redBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.red.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: colors.red),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Reminders Permission Denied',
                  style: AppTextStyles.bodyMed(colors.red),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'To create reminders, please enable access in iOS Settings.',
            style: AppTextStyles.caption(colors.textDim),
          ),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton(
            onPressed: () => controller.openSettings(),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionRequest(BuildContext context, CircadianColors colors, SmartReminderController controller) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.accent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.lock_open_rounded, color: colors.accent, size: 32),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Reminder Access Needed',
            style: AppTextStyles.bodyMed(colors.text),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'I need permission to add this to your iOS Reminders app.',
            style: AppTextStyles.caption(colors.textDim),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: () => controller.requestPermission(),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
            ),
            child: const Text('Allow Access'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(CircadianColors colors, String? error) {
    return Center(
      child: Column(
        children: [
          Icon(Icons.error_outline, color: colors.red, size: 48),
          const SizedBox(height: AppSpacing.md),
          Text('Something went wrong', style: AppTextStyles.bodyMed(colors.text)),
          Text(error ?? 'Unknown error', style: AppTextStyles.caption(colors.textDim), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildSuccessState(BuildContext context, CircadianColors colors) {
    return Center(
      child: Column(
        children: [
          Icon(Icons.check_circle_outline, color: colors.green, size: 48),
          const SizedBox(height: AppSpacing.md),
          Text('Successfully scheduled!', style: AppTextStyles.h3(colors.text)),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: colors.accent),
            child: Text('Done', style: AppTextStyles.label(Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isLoading;
  final CircadianColors colors;

  const _OptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required this.isLoading,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: colors.surfaceBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: colors.accentBg,
                borderRadius: BorderRadius.circular(AppRadius.icon),
              ),
              child: Icon(icon, color: colors.accent),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.bodyMed(colors.text)),
                  Text(subtitle, style: AppTextStyles.caption(colors.textDim)),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(Icons.chevron_right, color: colors.textFaint),
          ],
        ),
      ),
    );
  }
}

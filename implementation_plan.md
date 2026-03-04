# Theme Inconsistencies Refactoring Plan

This plan will clean up hardcoded colors explicitly causing cards and rows to appear static or incorrectly colored in respect to Light/Dark mode variants.  

## Proposed Changes

### Theme Handling and Application Core
- Modify `AppColors` fields from `Colors.white` / `Colors.black` specific settings into actual dynamic configurations relying on flutter's UI brightness logic using `BuildContext`, or modifying the provider to re-initialize colors correctly upon Theme Switching. Wait, static properties in Dart won't dynamically return state unless they're getters querying some configuration state like the bool `isDark`! BUT Flutter doesn't redraw unlinked static getters properly if the widget doesn't know the state updated. We must update the `SettingsPage` to dynamically rebuild using actual `Theme` configurations inside components.

#### [MODIFY] `lib/core/theme/app_theme.dart`
- Validate `AppColors.isDark` relies on its getter, which currently works, but Flutter app components directly call `AppColors.background` inside stateless/stateful widgets instead of `Theme.of(context).colorScheme.surface`. Static strings don't invoke widget rebuilds without proper observers!

#### [MODIFY] `lib/features/analytics/presentation/settingspage.dart`
- Remove hardcoded `Colors.blue` and `Colors.redAccent`. Change to `Theme.of(context).colorScheme.primary` or related.
- Remove hardcoded logic from titles.

#### [MODIFY] `lib/screens/brain_dump_screen.dart`
- Remove explicit `AppColors.background` inside widgets causing them not to properly request redraw via Riverpod theme mode context triggers unless the specific builder watches the theme provider. Currently they just use `AppColors.background`. Instead of tracking down every single widget missing a `watch`, adapt widget background color references to use `Theme.of(context).scaffoldBackgroundColor`.

## Verification Plan
1. Launch app using hot-restart since theme config modifications are required.
2. Toggle theming on SettingsPage and check if color properties map to respective widgets properly.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_theme.dart';

class ThemeModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    return true; // Default to dark mode
  }

  void toggleTheme() {
    state = !state;
    if (state) {
      AppColors.setDark();
    } else {
      AppColors.setLight();
    }
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, bool>(() {
  return ThemeModeNotifier();
});

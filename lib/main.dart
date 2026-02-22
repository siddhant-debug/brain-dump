import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'screens/brain_dump_screen.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userProvider);

    return MaterialApp(
      title: 'Brain Dump',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: userState.when(
        data: (user) {
          if (user != null) {
            final isNewUser = ref.watch(isNewUserProvider);
            if (isNewUser) return const OnboardingScreen();
            return const BrainDumpScreen();
          } else {
            return const LoginScreen();
          }
        },
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, stack) =>
            Scaffold(body: Center(child: Text('Error: $err'))),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        colorScheme: ColorScheme.dark(
          surface: const Color(0xFF0D0D0D),
          primary: Colors.white.withValues(alpha: 0.85),
          secondary: Colors.white.withValues(alpha: 0.40),
        ),
        fontFamily: 'sans-serif',
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: Colors.white.withValues(alpha: 0.7),
          selectionColor: Colors.white.withValues(alpha: 0.15),
          selectionHandleColor: Colors.white.withValues(alpha: 0.5),
        ),
        useMaterial3: true,
      ),
      home: userState.when(
        data: (user) {
          if (user != null) {
            final isNewUser = ref.watch(isNewUserProvider);
            // If new user -> Onboarding, else -> Dashboard
            if (isNewUser) {
              return const OnboardingScreen();
            }
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:brain_dump/features/onboarding/screens/onboarding_screen.dart';
import 'package:brain_dump/screens/brain_dump_screen.dart';
import 'package:brain_dump/features/auth/controllers/auth_controller.dart';
import 'package:brain_dump/features/auth/presentation/login_screen.dart';

void main() {
  // [Architect] Root of the Riverpod State Management System.
  // ProviderScope stores all the state (Providers) and makes them accessible
  // to any widget in the tree via a `ref` object.
  runApp(const ProviderScope(child: BrainDumpApp()));
}

class BrainDumpApp extends ConsumerWidget {
  const BrainDumpApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(isAuthenticatedProvider);
    /*
    1 : final authState = ref.watch(isAuthenticatedProvider);
    is used to watch the isAuthenticatedProvider.
    */

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
      ),
      home: authState.when(
        /*
        2 : authState.when(
        is used to watch the authState.
        based on the state it returns the appropriate widget.
        it check is isAuthenticated is true or false.
        if true it returns the OnboardingScreen or BrainDumpScreen.
        onboarding screen is shown if isNewUser is true.
        brain dump screen is shown if isNewUser is false.
        if false it returns the LoginScreen.
        */

        data: (isAuthenticated) {
          if (isAuthenticated) {
            final isNewUser = ref.watch(isNewUserProvider);
            /*
            2 : final isNewUser = ref.watch(isNewUserProvider);
            is used to watch the isNewUserProvider.
            */
            return isNewUser
                ? const OnboardingScreen()
                : const BrainDumpScreen();
          }
          return const LoginScreen();
          /*
          3 : return const LoginScreen();
          is used to return the LoginScreen.
          */
        },
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, __) => const LoginScreen(),
        /*
        4 : error: (_, __) => const LoginScreen(),
        is used to return the LoginScreen.
        */
      ),
    );
  }
}

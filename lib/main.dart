import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/onboarding/screens/life_path_onboarding_screen.dart';
import 'screens/dashboard_screen.dart';
import 'package:music_kit/music_kit.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Apple MusicKit with the generated Developer JWT
  try {
    final musicToken = dotenv.env['APPLE_MUSIC_JWT'] ?? '';
    if (musicToken.isNotEmpty) {
      await MusicKit().initialize(musicToken);
    } else {
      debugPrint("Warning: APPLE_MUSIC_JWT is empty or not found in .env");
    }
  } catch (e) {
    debugPrint("Failed to initialize MusicKit: $e");
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userProvider);
    final themeState = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Brain Dump',
      debugShowCheckedModeBanner: false,
      theme: themeState.themeData,
      home: userState.when(
        data: (user) {
          if (user != null) {
            if (!user.hasCompletedLifePath) {
              return const LifePathOnboardingScreen();
            }
            return const DashboardScreen();
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

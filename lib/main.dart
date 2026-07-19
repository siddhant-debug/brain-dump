import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/onboarding/screens/life_path_onboarding_screen.dart';
import 'screens/dashboard_screen.dart';
import 'package:music_kit/music_kit.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// IMPROVEMENT: Area 1 — Capture Friction
import 'package:home_widget/home_widget.dart';
import 'package:uni_links/uni_links.dart';
import 'dart:async';
import 'screens/brain_dump_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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

  // IMPROVEMENT: Area 1 — Initialize home widget callback for cold starts
  WidgetsFlutterBinding.ensureInitialized();
  HomeWidget.setAppGroupId('group.com.siddhant.braindump'); // Matches iOS widget and Xcode App Group

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    
    // IMPROVEMENT: Area 1 — Capture Friction (listen to widget clicks)
    HomeWidget.widgetClicked.listen((Uri? uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });

    // Check for cold start from widget
    HomeWidget.initiallyLaunchedFromHomeWidget().then((Uri? uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });
  }

  void _initDeepLinks() {
    // Check initial link
    getInitialUri().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });

    // Listen for incoming links while app is running
    _sub = uriLinkStream.listen((Uri? uri) {
      if (uri != null) _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    if (uri.path == '/capture' || uri.host == 'capture') {
      final mode = uri.queryParameters['mode'];
      final input = uri.queryParameters['input'];
      
      navigatorKey.currentState?.pushNamed(
        '/capture',
        arguments: {
          'mode': mode,
          'input': input,
        },
      );
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final themeState = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Brain Dump',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: themeState.themeData,
      // IMPROVEMENT: Area 1 — Capture route
      onGenerateRoute: (settings) {
        if (settings.name == '/capture') {
          final args = settings.arguments as Map<String, dynamic>?;
          final mode = args?['mode'];
          final input = args?['input'];
          return MaterialPageRoute(
            builder: (context) => BrainDumpScreen(
              startInJournal: mode == 'journal',
              autoTriggerMic: input == 'voice',
            ),
          );
        }
        return null;
      },
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

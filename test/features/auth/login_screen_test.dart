import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:brain_dump/features/auth/presentation/login_screen.dart';
import 'package:brain_dump/features/auth/controllers/auth_controller.dart';

class FakeAuthController extends StateNotifier<AsyncValue<void>>
    implements AuthController {
  FakeAuthController() : super(const AsyncValue.data(null));

  bool loginCalled = false;
  bool signupCalled = false;

  @override
  Future<void> login(String email, String password) async {
    loginCalled = true;
    state = const AsyncValue.loading();
  }

  @override
  Future<void> signup(String email, String password, {String? fullName}) async {
    signupCalled = true;
    state = const AsyncValue.loading();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('LoginScreen Tests', () {
    testWidgets('renders login UI correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LoginScreen())),
      );

      expect(find.text('Brain Dump'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Need an account? Sign Up'), findsOneWidget);
    });

    testWidgets('toggles between login and signup', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LoginScreen())),
      );

      // Initially Login
      expect(find.text('Login'), findsOneWidget);

      // Tap toggle
      await tester.tap(find.text('Need an account? Sign Up'));
      await tester.pump();

      // Now Signup
      expect(find.text('Sign Up'), findsOneWidget);
      expect(find.text('Already have an account? Login'), findsOneWidget);
    });

    testWidgets('shows warning snackbar if fields are empty', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LoginScreen())),
      );

      await tester.tap(find.text('Login'));
      await tester.pump(); // trigger tick

      expect(find.text('Please fill in all fields'), findsOneWidget);
    });

    testWidgets('calls login on the controller when form is filled', (
      WidgetTester tester,
    ) async {
      final fakeController = FakeAuthController();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => fakeController),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'test@test.com');
      await tester.enterText(find.byType(TextField).last, 'password123');
      await tester.tap(find.text('Login'));
      await tester.pump();

      expect(fakeController.loginCalled, isTrue);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/features/account/data/profile_store.dart';
import 'package:oxro/features/auth/presentation/screens/login_screen.dart';
import 'package:oxro/features/auth/presentation/screens/otp_screen.dart';

/// Multiple frames so switcher transitions + route animations complete
/// and outgoing forms are fully unmounted before field indexing.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// Multiple frames so route transitions + delayed futures complete.
Future<void> _pumpFrames(WidgetTester tester,
    [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _dispose(WidgetTester tester) async {
  // Unmount to cancel timers/animation controllers.
  await tester.pumpWidget(Container());
}

/// Scroll the signup submit button into view (short screens) then tap it.
Future<void> _tapCreateAccount(WidgetTester tester) async {
  final btn = find.text('Create Account').last;
  await tester.ensureVisible(btn);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(btn);
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProfileStore.resetForTests();
  });

  testWidgets('Login rejects bad email with error', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: LoginScreen()));
    await _settle(tester);

    await tester.tap(find.text('Continue'));
    await _settle(tester);
    expect(find.text('Enter your email address'), findsOneWidget);

    await tester.enterText(
        find.byType(TextField), 'notanemail');
    await tester.tap(find.text('Continue'));
    await _settle(tester);
    expect(
        find.text('Enter valid email address'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Login valid email goes to OTP', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: LoginScreen()));
    await _settle(tester);

    await tester.enterText(
        find.byType(TextField), 'priya@example.com');
    await tester.tap(find.text('Continue'));
    await _pumpFrames(tester);
    expect(find.text('Verify Your Number'), findsOneWidget);
    expect(find.textContaining('priya@example.com'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Tabs switch Login/SignUp forms', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: LoginScreen()));
    await _settle(tester);

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.text('Sign Up'));
    await _settle(tester);
    expect(find.text('Create Account'), findsWidgets);
    expect(find.byType(TextField), findsNWidgets(3));

    await tester.tap(find.text('Login'));
    await _settle(tester);
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('SignUp validates name then goes to OTP',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: LoginScreen()));
    await _settle(tester);
    await tester.tap(find.text('Sign Up'));
    await _settle(tester);

    // Empty submit → name + email errors.
    await _tapCreateAccount(tester);
    await _settle(tester);
    expect(find.text('Enter your full name'), findsOneWidget);
    expect(find.text('Enter your email address'), findsOneWidget);

    // Bad name + bad email.
    await tester.enterText(
        find.byType(TextField).at(0), 'A1');
    await tester.enterText(
        find.byType(TextField).at(1), 'notanemail');
    await _tapCreateAccount(tester);
    await _settle(tester);
    expect(find.text('Enter a valid name (min 3 letters)'),
        findsOneWidget);

    // Valid → OTP.
    await tester.enterText(
        find.byType(TextField).at(0), 'Priya');
    await tester.enterText(
        find.byType(TextField).at(1), 'priya@example.com');
    await _tapCreateAccount(tester);
    await _pumpFrames(tester);
    expect(find.text('Verify Your Number'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('SignUp OTP success welcomes new user', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: LoginScreen()));
    await _settle(tester);
    await tester.tap(find.text('Sign Up'));
    await _settle(tester);
    await tester.enterText(
        find.byType(TextField).at(0), 'Priya');
    await tester.enterText(
        find.byType(TextField).at(1), 'priya@example.com');
    await _tapCreateAccount(tester);
    await _pumpFrames(tester);

    for (var i = 0; i < 6; i++) {
      await tester.enterText(
          find.byType(TextField).at(i), '${i + 1}');
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('Verify'));
    await _pumpFrames(tester, 8);
    expect(find.textContaining('Welcome to OXRO, Priya!'),
        findsNothing);
    expect(find.byKey(const ValueKey('home_quick_cats')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('OTP fields fill via keyboard and verify to home',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: OtpScreen(contact: 'priya@example.com')));
    await _settle(tester);

    // Autofocus opens the phone keyboard on entry.
    expect(tester.testTextInput.isVisible, isTrue);

    // Verify with empty boxes shows error.
    await tester.tap(find.text('Verify'));
    await _settle(tester);
    expect(find.text('Enter all 6 digits'), findsOneWidget);

    for (var i = 0; i < 6; i++) {
      await tester.enterText(
          find.byType(TextField).at(i), '${i + 1}');
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('Verify'));
    await tester.pump(const Duration(milliseconds: 300));
    // Success burst animation visible.
    expect(find.byKey(const ValueKey('otp_success_tick')),
        findsOneWidget);
    await _pumpFrames(tester, 6);
    expect(find.text('OXRO Home'), findsNothing);
    expect(find.byKey(const ValueKey('home_quick_cats')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('OTP paste distributes across boxes', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: OtpScreen(contact: 'priya@example.com')));
    await _settle(tester);

    await tester.enterText(
        find.byType(TextField).at(0), '123456');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Verify'));
    await _pumpFrames(tester, 8);
    expect(find.text('OXRO Home'), findsNothing);
    expect(find.byKey(const ValueKey('home_quick_cats')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('OTP backspace clears last digit', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: OtpScreen(contact: 'priya@example.com')));
    await _settle(tester);

    await tester.enterText(
        find.byType(TextField).at(0), '7');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(
        find.byType(TextField).at(0), '');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Verify'));
    await _settle(tester);
    expect(find.text('Enter all 6 digits'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Login 320 + OTP 320 no overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
        const MaterialApp(home: LoginScreen()));
    await _settle(tester);
    expect(tester.takeException(), isNull);

    // Signup form is taller — also must fit 320x568.
    await tester.tap(find.text('Sign Up'));
    await _settle(tester);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const MaterialApp(
        home: OtpScreen(contact: 'priya@example.com')));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });
}

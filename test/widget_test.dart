import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/app/app.dart';
import 'package:oxro/features/account/data/profile_store.dart';

void main() {
  testWidgets('Splash shows OXRO branding', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    ProfileStore.resetForTests();
    await tester.pumpWidget(const MyApp());

    expect(find.text('OXRO'), findsOneWidget);
    expect(find.text('Shop More  Live Better'), findsOneWidget);
    expect(find.text('v1.0.0'), findsOneWidget);

    // Let splash boot (prefs load + brand delay) navigate.
    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Skip >'), findsOneWidget);
    ProfileStore.resetForTests();
  });
}

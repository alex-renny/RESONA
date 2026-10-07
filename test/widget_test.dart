import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:resona/features/projects/application/projects_provider.dart';
import 'package:resona/main.dart';

void main() {
  testWidgets('App smoke test — home screen renders', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recentProjectsProvider.overrideWith((ref) async => []),
        ],
        child: const ResonaApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('RESONA'), findsWidgets);
  });
}

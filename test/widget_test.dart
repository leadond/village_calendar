import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_calendar/main.dart';
import 'package:village_calendar/src/services/setup_services.dart';
import 'package:village_calendar/src/state/providers.dart';

void main() {
  testWidgets('shows the landing screen when backend is not configured',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          setupStatusProvider.overrideWithValue(
            const SetupStatus(
              supabaseConfigured: false,
              firebaseConfigured: false,
              revenueCatConfigured: false,
            ),
          ),
        ],
        child: const VillageCalendarApp(),
      ),
    );

    // Supabase is not initialized in tests, so RootGate falls back to the
    // landing page.
    expect(find.text('Welcome to Village Calendar'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });
}

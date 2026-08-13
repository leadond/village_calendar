import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_calendar/main.dart';
import 'package:village_calendar/src/services/setup_services.dart';
import 'package:village_calendar/src/state/providers.dart';

void main() {
  testWidgets('app builds and renders a MaterialApp', (tester) async {
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
        child: VillageCalendarApp(navigatorKey: GlobalKey<NavigatorState>()),
      ),
    );
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

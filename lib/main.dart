import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/authentication.dart';
import 'src/app/root_gate.dart';
import 'src/services/setup_services.dart';
import 'src/state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final setupStatus = await SetupServices.initialize();

  runApp(
    ProviderScope(
      overrides: [setupStatusProvider.overrideWithValue(setupStatus)],
      child: const VillageCalendarApp(),
    ),
  );
}

class VillageCalendarApp extends StatelessWidget {
  const VillageCalendarApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2F6F5E),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Village Calendar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        textTheme: GoogleFonts.interTextTheme(),
        useMaterial3: true,
      ),
      // RootGate decides what to show based on auth + profile + village state.
      home: const RootGate(),
      routes: {
        '/auth': (context) => const AuthenticationScreen(),
      },
    );
  }
}

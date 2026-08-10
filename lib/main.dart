import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/services/notification_service.dart';
import 'screens/app_preview.dart';
import 'screens/authentication.dart';
import 'screens/update_password_screen.dart';
import 'src/app/root_gate.dart';
import 'src/services/setup_services.dart';
import 'src/state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter bootstrap error: ${details.exceptionAsString()}');
  };

  final setupStatus = await SetupServices.initialize();
  await NotificationService.instance.initialize();

  runApp(
    ProviderScope(
      overrides: [
        setupStatusProvider.overrideWithValue(setupStatus),
      ],
      child: const VillageCalendarBootstrap(),
    ),
  );
}

class VillageCalendarBootstrap extends StatefulWidget {
  const VillageCalendarBootstrap({super.key});

  @override
  State<VillageCalendarBootstrap> createState() =>
      _VillageCalendarBootstrapState();
}

class _VillageCalendarBootstrapState extends State<VillageCalendarBootstrap> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  bool _recoveryRouteOpen = false;

  @override
  void initState() {
    super.initState();
    final client = SetupServices.maybeSupabaseClient;
    if (client != null) {
      _authSubscription = client.auth.onAuthStateChange.listen((state) {
        if (state.event == AuthChangeEvent.passwordRecovery &&
            !_recoveryRouteOpen) {
          _recoveryRouteOpen = true;
          _navigatorKey.currentState
              ?.pushNamed('/update-password')
              .whenComplete(() => _recoveryRouteOpen = false);
        }
      });
    }

    if (SetupServices.isFirebaseReady) {
      _messageSubscription = FirebaseMessaging.onMessage.listen((message) async {
        final notification = message.notification;
        final title = notification?.title ?? message.data['title'] as String?;
        final body = notification?.body ?? message.data['body'] as String?;

        if (title == null && body == null) {
          return;
        }

        await NotificationService.instance.showNotification(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          title: title ?? 'My Village Pro',
          body: body ?? 'You have a new update.',
          payload: message.data.map(
            (key, value) => MapEntry(key, value.toString()),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _messageSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VillageCalendarApp(navigatorKey: _navigatorKey);
  }
}

class VillageCalendarApp extends StatelessWidget {
  const VillageCalendarApp({super.key, required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'My Village Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      routes: {
        '/auth': (_) => const AuthenticationScreen(),
        '/preview': (_) => const AppPreviewScreen(),
        '/update-password': (_) => const UpdatePasswordScreen(),
      },
      home: const RootGate(),
    );
  }
}

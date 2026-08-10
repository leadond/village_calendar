import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const revenueCatApiKey = String.fromEnvironment('REVENUECAT_API_KEY');
  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const firebaseAuthDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
  );
  static const firebaseStorageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );
  static const firebaseWebVapidKey = String.fromEnvironment(
    'FIREBASE_WEB_VAPID_KEY',
  );
  static const firebaseMessagingEnabled = bool.fromEnvironment(
    'FIREBASE_MESSAGING_ENABLED',
  );
  static const googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  static const nvidiaModel = String.fromEnvironment(
    'NVIDIA_MODEL',
    defaultValue: 'nvidia/llama-3.1-nemotron-nano-8b-v1',
  );

  static bool get hasGoogleMapsKey => googleMapsApiKey.isNotEmpty;

  /// RevenueCat Web Billing public key (used on Flutter web via the JS bridge).
  /// Defaults to the sandbox/test key; override with --dart-define for prod.
  static const revenueCatWebApiKey = String.fromEnvironment(
    'REVENUECAT_WEB_API_KEY',
    defaultValue: 'test_qeVgqUcpbgLSQIRIiKClErHwoyh',
  );

  /// The RevenueCat entitlement identifier that unlocks premium.
  static const revenueCatEntitlementId = String.fromEnvironment(
    'REVENUECAT_ENTITLEMENT_ID',
    defaultValue: 'pro',
  );

  static bool get hasSupabaseCredentials =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get hasRevenueCatKey => revenueCatApiKey.isNotEmpty;

  static bool get hasFirebaseWebConfig =>
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseMessagingSenderId.isNotEmpty &&
      firebaseProjectId.isNotEmpty;

  static FirebaseOptions get firebaseWebOptions => FirebaseOptions(
    apiKey: firebaseApiKey,
    appId: firebaseAppId,
    messagingSenderId: firebaseMessagingSenderId,
    projectId: firebaseProjectId,
    authDomain: firebaseAuthDomain.isEmpty ? null : firebaseAuthDomain,
    storageBucket: firebaseStorageBucket.isEmpty ? null : firebaseStorageBucket,
  );
}

class SetupStatus {
  const SetupStatus({
    required this.supabaseConfigured,
    required this.firebaseConfigured,
    required this.revenueCatConfigured,
    this.firebaseMessagingToken,
    this.warnings = const <String>[],
  });

  final bool supabaseConfigured;
  final bool firebaseConfigured;
  final bool revenueCatConfigured;
  final String? firebaseMessagingToken;
  final List<String> warnings;

  bool get isFullyConfigured =>
      supabaseConfigured && firebaseConfigured && revenueCatConfigured;
}

class SetupServices {
  static bool _supabaseInitialized = false;
  static bool _firebaseInitialized = false;
  static bool _revenueCatInitialized = false;

  static bool get isSupabaseReady => _supabaseInitialized;
  static bool get isFirebaseReady => _firebaseInitialized;
  static bool get isRevenueCatReady => _revenueCatInitialized;
  static bool get isFirebaseMessagingConfigured {
    if (!AppConfig.firebaseMessagingEnabled) {
      return false;
    }

    if (kIsWeb) {
      return AppConfig.hasFirebaseWebConfig &&
          AppConfig.firebaseWebVapidKey.isNotEmpty;
    }

    return true;
  }

  static SupabaseClient? get maybeSupabaseClient {
    if (!_supabaseInitialized) {
      return null;
    }

    return Supabase.instance.client;
  }

  static SupabaseClient get supabaseClient {
    final client = maybeSupabaseClient;
    if (client == null) {
      throw StateError(
        'Supabase has not been initialized. Provide SUPABASE_URL and '
        'SUPABASE_ANON_KEY with --dart-define before using Supabase.',
      );
    }

    return client;
  }

  static Future<SetupStatus> initialize() async {
    final warnings = <String>[];

    final supabaseConfigured = await _initializeSupabase(warnings);
    final firebaseMessagingToken = await _initializeFirebaseMessaging(warnings);
    final revenueCatConfigured = await _initializeRevenueCat(warnings);

    return SetupStatus(
      supabaseConfigured: supabaseConfigured,
      firebaseConfigured: _firebaseInitialized,
      revenueCatConfigured: revenueCatConfigured,
      firebaseMessagingToken: firebaseMessagingToken,
      warnings: warnings,
    );
  }

  static Future<bool> _initializeSupabase(List<String> warnings) async {
    if (!AppConfig.hasSupabaseCredentials) {
      warnings.add(
        'Supabase skipped. Pass SUPABASE_URL and SUPABASE_ANON_KEY with '
        '--dart-define when you are ready to connect the backend.',
      );
      return false;
    }

    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      );
      _supabaseInitialized = true;
      return true;
    } catch (error, stackTrace) {
      warnings.add('Supabase initialization failed: $error');
      debugPrintStack(label: error.toString(), stackTrace: stackTrace);
      return false;
    }
  }

  static Future<String?> _initializeFirebaseMessaging(
    List<String> warnings,
  ) async {
    if (!AppConfig.firebaseMessagingEnabled) {
      warnings.add(
        'Firebase Messaging skipped. Pass FIREBASE_MESSAGING_ENABLED=true '
        'after Firebase is configured.',
      );
      return null;
    }

    if (kIsWeb && !AppConfig.hasFirebaseWebConfig) {
      warnings.add(
        'Firebase Messaging skipped on web. Pass FIREBASE_API_KEY, '
        'FIREBASE_APP_ID, FIREBASE_MESSAGING_SENDER_ID, and '
        'FIREBASE_PROJECT_ID with --dart-define after creating your Firebase '
        'web app.',
      );
      return null;
    }

    if (kIsWeb && AppConfig.firebaseWebVapidKey.isEmpty) {
      warnings.add(
        'Firebase Messaging skipped on web. Pass FIREBASE_WEB_VAPID_KEY with '
        '--dart-define after generating a Web Push certificate in Firebase.',
      );
      return null;
    }

    try {
      await Firebase.initializeApp(
        options: kIsWeb ? AppConfig.firebaseWebOptions : null,
      );
      _firebaseInitialized = true;

      if (kIsWeb) {
        return null;
      }

      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final isAuthorized =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (!isAuthorized) {
        warnings.add('Firebase messaging permission was not granted.');
        return null;
      }

      final token = kIsWeb
          ? await messaging.getToken(vapidKey: AppConfig.firebaseWebVapidKey)
          : await messaging.getToken();
      debugPrint('Firebase Messaging Token: $token');
      return token;
    } catch (error, stackTrace) {
      _firebaseInitialized = false;
      warnings.add(
        'Firebase Messaging skipped. Add platform Firebase config files or run '
        '`flutterfire configure`: $error',
      );
      debugPrintStack(label: error.toString(), stackTrace: stackTrace);
      return null;
    }
  }

  static Future<bool> _initializeRevenueCat(List<String> warnings) async {
    if (!AppConfig.hasRevenueCatKey) {
      return false;
    }

    try {
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);

      final configuration = PurchasesConfiguration(AppConfig.revenueCatApiKey);
      final appUserId = maybeSupabaseClient?.auth.currentUser?.id;

      if (appUserId != null) {
        configuration.appUserID = appUserId;
      }

      await Purchases.configure(configuration);
      _revenueCatInitialized = true;
      return true;
    } catch (error, stackTrace) {
      _revenueCatInitialized = false;
      warnings.add('RevenueCat initialization failed: $error');
      debugPrintStack(label: error.toString(), stackTrace: stackTrace);
      return false;
    }
  }

  static Future<void> _ensureFirebaseInitialized() async {
    if (_firebaseInitialized) {
      return;
    }

    await Firebase.initializeApp(
      options: kIsWeb ? AppConfig.firebaseWebOptions : null,
    );
    _firebaseInitialized = true;
  }

  static Future<String?> getFirebaseMessagingToken({
    bool requestPermission = false,
  }) async {
    if (!isFirebaseMessagingConfigured) {
      return null;
    }

    await _ensureFirebaseInitialized();
    final messaging = FirebaseMessaging.instance;

    if (requestPermission) {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final isAuthorized =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (!isAuthorized) {
        return null;
      }
    }

    return kIsWeb
        ? await messaging.getToken(vapidKey: AppConfig.firebaseWebVapidKey)
        : await messaging.getToken();
  }
}

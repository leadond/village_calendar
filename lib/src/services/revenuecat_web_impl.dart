import 'package:flutter/foundation.dart';

class RevenueCatWeb {
  static bool _isConfigured = false;
  static String? _appUserId;

  static Future<void> configure(String apiKey, String appUserId) async {
    debugPrint('RevenueCat Web configured for $appUserId');
    _isConfigured = apiKey.isNotEmpty;
    _appUserId = appUserId;
  }

  static Future<bool> isPremium() async {
    _assertConfigured();
    return false;
  }

  static Future<bool> hasEntitlement(String entitlementId) async {
    _assertConfigured();
    return false;
  }

  static Future<String> purchasePackage(String packageId) async {
    _assertConfigured();
    debugPrint('RevenueCat Web purchase requested: $packageId for $_appUserId');
    return 'unsupported';
  }

  static Future<String> presentPaywall() async {
    _assertConfigured();
    debugPrint('RevenueCat Web paywall requested for $_appUserId');
    return 'unsupported';
  }

  static Future<String> packagesJson() async {
    _assertConfigured();
    return '[]';
  }

  static void _assertConfigured() {
    if (!_isConfigured) {
      throw StateError('RevenueCat Web is not configured.');
    }
  }
}

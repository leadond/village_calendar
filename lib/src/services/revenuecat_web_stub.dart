/// No-op stub for non-web platforms (mobile uses purchases_flutter instead).
class RevenueCatWeb {
  static Future<void> configure(String apiKey, String appUserId) async {}
  static Future<bool> isPremium() async => false;
  static Future<bool> hasEntitlement(String entitlementId) async => false;
  static Future<String> purchasePackage(String packageId) async => 'unsupported';
  static Future<String> presentPaywall() async => 'unsupported';
  static Future<String> packagesJson() async => '[]';
}

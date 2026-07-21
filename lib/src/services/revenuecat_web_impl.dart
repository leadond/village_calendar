// Web implementation: calls window.RCWeb.* (defined in web/revenuecat_bridge.js)
// through dart:js_interop. Each JS function returns a Promise of a simple value.
import 'dart:js_interop';

@JS('RCWeb')
external _RCWebJs get _rcWeb;

extension type _RCWebJs(JSObject _) implements JSObject {
  external JSPromise<JSBoolean> configure(String apiKey, String appUserId);
  external JSPromise<JSBoolean> isPremium();
  external JSPromise<JSBoolean> hasEntitlement(String entitlementId);
  external JSPromise<JSString> purchasePackage(String packageId);
  external JSPromise<JSString> presentPaywall();
  external JSPromise<JSString> getPackagesJson();
}

class RevenueCatWeb {
  static Future<void> configure(String apiKey, String appUserId) async {
    await _rcWeb.configure(apiKey, appUserId).toDart;
  }

  static Future<bool> isPremium() async {
    final r = await _rcWeb.isPremium().toDart;
    return r.toDart;
  }

  static Future<bool> hasEntitlement(String entitlementId) async {
    final r = await _rcWeb.hasEntitlement(entitlementId).toDart;
    return r.toDart;
  }

  /// Returns: success | no_entitlement | cancelled | not_found | error.
  static Future<String> purchasePackage(String packageId) async {
    final r = await _rcWeb.purchasePackage(packageId).toDart;
    return r.toDart;
  }

  /// Presents the RevenueCat-hosted paywall.
  /// Returns: success | dismissed | cancelled | error.
  static Future<String> presentPaywall() async {
    final r = await _rcWeb.presentPaywall().toDart;
    return r.toDart;
  }

  static Future<String> packagesJson() async {
    final r = await _rcWeb.getPackagesJson().toDart;
    return r.toDart;
  }
}

// Facade that resolves to the web js_interop implementation on web, and a no-op
// stub elsewhere (so iOS/Android — which use purchases_flutter — still compile).
export 'revenuecat_web_stub.dart'
    if (dart.library.js_interop) 'revenuecat_web_impl.dart';

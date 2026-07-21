// RevenueCat Web SDK bridge for the Flutter web app.
// Loads @revenuecat/purchases-js and exposes a small async API on window.RCWeb
// that the Dart (dart:js_interop) layer calls. All functions resolve to simple
// JSON-serializable values so they cross the JS<->Dart boundary cleanly.
//
// Docs: https://www.revenuecat.com/docs/web/web-billing/web-sdk
import {
  Purchases,
  PurchasesError,
  ErrorCode,
} from "https://esm.sh/@revenuecat/purchases-js@1.13.2";

let purchases = null;

function instance() {
  return purchases ?? Purchases.getSharedInstance();
}

// Configure once. appUserId MUST be your Supabase auth user id so the
// RevenueCat webhook can update the right profile row.
async function configure(apiKey, appUserId) {
  if (purchases) return true;
  purchases = Purchases.configure({ apiKey, appUserId });
  return true;
}

// True if the customer has ANY active entitlement (the app has a single paid
// tier). Use hasEntitlement(id) if you need a specific one.
async function isPremium() {
  try {
    const info = await instance().getCustomerInfo();
    return Object.keys(info.entitlements.active).length > 0;
  } catch (e) {
    console.error("[RCWeb] isPremium", e);
    return false;
  }
}

async function hasEntitlement(entitlementId) {
  try {
    const info = await instance().getCustomerInfo();
    return entitlementId in info.entitlements.active;
  } catch (e) {
    console.error("[RCWeb] hasEntitlement", e);
    return false;
  }
}

// Returns the current offering's packages as JSON (id, product, title, price).
async function getPackagesJson() {
  try {
    const offerings = await instance().getOfferings();
    const cur = offerings.current;
    if (!cur) return "[]";
    const pkgs = cur.availablePackages.map((p) => {
      const prod = p.webBillingProduct ?? {};
      const price = prod.currentPrice ?? {};
      return {
        id: p.identifier,
        productId: prod.identifier ?? "",
        title: prod.title ?? "",
        priceString: price.formattedPrice ?? "",
      };
    });
    return JSON.stringify(pkgs);
  } catch (e) {
    console.error("[RCWeb] getPackagesJson", e);
    return "[]";
  }
}

// Purchase a package by its identifier. Returns: success | no_entitlement |
// cancelled | not_found | error.
async function purchasePackage(packageId) {
  try {
    const offerings = await instance().getOfferings();
    const cur = offerings.current;
    const pkg =
      (cur && cur.packagesById && cur.packagesById[packageId]) ||
      (cur && cur.availablePackages.find((p) => p.identifier === packageId));
    if (!pkg) return "not_found";
    const { customerInfo } = await instance().purchase({ rcPackage: pkg });
    return Object.keys(customerInfo.entitlements.active).length > 0
      ? "success"
      : "no_entitlement";
  } catch (e) {
    if (e instanceof PurchasesError && e.errorCode === ErrorCode.UserCancelledError) {
      return "cancelled";
    }
    console.error("[RCWeb] purchasePackage", e);
    return "error";
  }
}

// Present the RevenueCat-hosted paywall. Returns: success | dismissed |
// cancelled | error.
async function presentPaywall() {
  try {
    let target = document.getElementById("rc-paywall-container");
    if (!target) {
      target = document.createElement("div");
      target.id = "rc-paywall-container";
      document.body.appendChild(target);
    }
    const result = await instance().presentPaywall({ htmlTarget: target });
    const active = result && result.customerInfo
      ? Object.keys(result.customerInfo.entitlements.active).length > 0
      : await isPremium();
    return active ? "success" : "dismissed";
  } catch (e) {
    if (e instanceof PurchasesError && e.errorCode === ErrorCode.UserCancelledError) {
      return "cancelled";
    }
    console.error("[RCWeb] presentPaywall", e);
    return "error";
  }
}

window.RCWeb = {
  configure,
  isPremium,
  hasEntitlement,
  getPackagesJson,
  purchasePackage,
  presentPaywall,
};
console.info("[RCWeb] bridge ready");

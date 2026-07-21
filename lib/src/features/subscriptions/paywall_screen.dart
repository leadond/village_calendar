import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../services/revenuecat_web.dart';
import '../../services/setup_services.dart';
import '../../state/providers.dart';

const _premiumFeatures = <(IconData, String, String)>[
  (Icons.groups, 'Multiple villages', 'Belong to more than one village at once.'),
  (Icons.my_location, 'Live GPS sharing', 'Share and follow live location on active trips.'),
  (Icons.sync, 'Carpool automation', 'Automatic rotation scheduling for carpools.'),
];

/// Returns true if the user is premium; otherwise shows the paywall and
/// returns false. Use to gate premium features.
Future<bool> requirePremium(BuildContext context, WidgetRef ref) async {
  if (ref.read(isPremiumProvider)) return true;
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const PaywallScreen()),
  );
  return ref.read(isPremiumProvider);
}

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _busy = false;

  Future<void> _upgrade() async {
    // Flutter web uses the RevenueCat Web SDK bridge (purchases_flutter is
    // mobile-only). On success, the RevenueCat webhook syncs subscription_tier.
    if (kIsWeb) {
      final uid = ref.read(currentUserProvider)?.id;
      if (uid == null) {
        _toast('Please sign in first.');
        return;
      }
      setState(() => _busy = true);
      try {
        await RevenueCatWeb.configure(AppConfig.revenueCatWebApiKey, uid);
        final result = await RevenueCatWeb.presentPaywall();
        switch (result) {
          case 'success':
            ref.invalidate(currentProfileProvider);
            if (mounted) Navigator.of(context).pop();
          case 'cancelled':
          case 'dismissed':
            break;
          default:
            _toast('Purchase did not complete ($result).');
        }
      } catch (e) {
        _toast('Paywall error: $e');
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    // --- mobile (purchases_flutter) ---
    if (!SetupServices.isRevenueCatReady) {
      _toast('Subscriptions are not configured yet. Add your RevenueCat keys '
          'to enable purchases.');
      return;
    }
    setState(() => _busy = true);
    try {
      final offerings = await Purchases.getOfferings();
      final packages = offerings.current?.availablePackages ?? const [];
      final pkg = packages.isNotEmpty ? packages.first : null;
      if (pkg == null) {
        _toast('No subscription products available. Configure them in '
            'RevenueCat.');
        return;
      }
      // ignore: deprecated_member_use
      await Purchases.purchasePackage(pkg);
      ref.invalidate(currentProfileProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _toast('Purchase did not complete: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (kIsWeb) {
      final uid = ref.read(currentUserProvider)?.id;
      if (uid == null) return;
      try {
        await RevenueCatWeb.configure(AppConfig.revenueCatWebApiKey, uid);
        final pro = await RevenueCatWeb.isPremium();
        ref.invalidate(currentProfileProvider);
        _toast(pro ? 'Premium restored.' : 'No active subscription found.');
      } catch (e) {
        _toast('Could not restore: $e');
      }
      return;
    }
    if (!SetupServices.isRevenueCatReady) {
      _toast('Subscriptions are not configured yet.');
      return;
    }
    try {
      await Purchases.restorePurchases();
      ref.invalidate(currentProfileProvider);
      _toast('Purchases restored.');
    } catch (e) {
      _toast('Could not restore: $e');
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Village Premium')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Icon(Icons.workspace_premium,
                size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text('Unlock Village Premium',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            for (final f in _premiumFeatures)
              ListTile(
                leading: Icon(f.$1),
                title: Text(f.$2),
                subtitle: Text(f.$3),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _upgrade,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Upgrade'),
            ),
            TextButton(
              onPressed: _busy ? null : _restore,
              child: const Text('Restore purchases'),
            ),
            const SizedBox(height: 8),
            Text(
              'Pricing and checkout are handled by the app store via RevenueCat '
              'once products are configured.',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

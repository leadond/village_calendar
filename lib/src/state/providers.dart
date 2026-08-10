import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';
import '../models/availability_block.dart';
import '../models/breadcrumb.dart';
import '../models/direct_message.dart';
import '../models/emergency_alert.dart';
import '../models/help_request.dart';
import '../models/join_request.dart';
import '../models/kid_profile.dart';
import '../models/message.dart';
import '../models/profile.dart';
import '../models/village.dart';
import '../repositories/announcement_repository.dart';
import '../repositories/availability_repository.dart';
import '../repositories/direct_message_repository.dart';
import '../repositories/emergency_repository.dart';
import '../repositories/gps_repository.dart';
import '../repositories/help_request_repository.dart';
import '../repositories/kid_repository.dart';
import '../repositories/message_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/profile_repository.dart';
import '../repositories/village_repository.dart';
import '../services/location_service.dart';
import '../services/ai_assistant_service.dart';
import '../services/google_maps_service.dart';
import '../services/setup_services.dart';

class AdminDashboardStats {
  const AdminDashboardStats({
    required this.memberCount,
    required this.pendingApprovals,
    required this.openRequests,
    required this.activeTrips,
    required this.announcementCount,
    required this.premiumMembers,
  });

  final int memberCount;
  final int pendingApprovals;
  final int openRequests;
  final int activeTrips;
  final int announcementCount;
  final int premiumMembers;
}

/// Injected in `main()` via a ProviderScope override.
final setupStatusProvider = Provider<SetupStatus>((ref) {
  throw UnimplementedError('setupStatusProvider must be overridden in main()');
});

final aiAssistantServiceProvider = Provider<AiAssistantService>((ref) {
  return const AiAssistantService();
});

final googleMapsServiceProvider = Provider<GoogleMapsService>((ref) {
  return const GoogleMapsService();
});

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return SetupServices.supabaseClient;
});

final adminDashboardStatsProvider = FutureProvider<AdminDashboardStats>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final role = ref.watch(activeRoleProvider);

  if (profile == null || !profile.hasVillage || role != UserRole.admin) {
    return const AdminDashboardStats(
      memberCount: 0,
      pendingApprovals: 0,
      openRequests: 0,
      activeTrips: 0,
      announcementCount: 0,
      premiumMembers: 0,
    );
  }

  final villageRepo = ref.watch(villageRepositoryProvider);
  final members = await villageRepo.activeVillageMembers();
  final pending = await villageRepo.pendingJoinRequests();
  final client = ref.watch(supabaseClientProvider);

  final openRows = await client
      .from('help_requests')
      .select('id')
      .eq('village_id', profile.villageId!)
      .eq('status', 'open');

  final activeRows = await client
      .from('help_requests')
      .select('id')
      .eq('village_id', profile.villageId!)
      .inFilter('status', ['confirmed', 'in_progress', 'arrived']);

  final announcementRows = await client
      .from('village_announcements')
      .select('id')
      .eq('village_id', profile.villageId!);

  final premiumMembers = members.where((member) {
    final tier = (member['subscription_tier'] as String?) ?? 'free';
    return tier != 'free' && tier.isNotEmpty;
  }).length;

  return AdminDashboardStats(
    memberCount: members.length,
    pendingApprovals: pending.length,
    openRequests: (openRows as List).length,
    activeTrips: (activeRows as List).length,
    announcementCount: (announcementRows as List).length,
    premiumMembers: premiumMembers,
  );
});

/// Stream of auth changes (sign-in / sign-out / token refresh).
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

/// The currently signed-in user, recomputed whenever auth state changes.
final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  return SetupServices.maybeSupabaseClient?.auth.currentUser;
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

final villageRepositoryProvider = Provider<VillageRepository>((ref) {
  return VillageRepository(ref.watch(supabaseClientProvider));
});

final kidRepositoryProvider = Provider<KidRepository>((ref) {
  return KidRepository(ref.watch(supabaseClientProvider));
});

/// The signed-in parent's kids.
final myKidsProvider = FutureProvider<List<KidProfile>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const <KidProfile>[];
  return ref.watch(kidRepositoryProvider).listForParent(user.id);
});

final helpRequestRepositoryProvider = Provider<HelpRequestRepository>((ref) {
  return HelpRequestRepository(ref.watch(supabaseClientProvider));
});

/// Help requests created by the signed-in user in the active village.
final myRequestsProvider = FutureProvider<List<HelpRequest>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null || !profile.hasVillage) return const <HelpRequest>[];
  return ref
      .watch(helpRequestRepositoryProvider)
      .myRequests(profile.id, profile.villageId!);
});

/// Open requests in the village that the helper can claim.
final availableRequestsProvider =
    FutureProvider<List<HelpRequest>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null || !profile.hasVillage) return const <HelpRequest>[];
  return ref
      .watch(helpRequestRepositoryProvider)
      .availableRequests(profile.villageId!, profile.id);
});

/// Requests the signed-in user has claimed as a helper.
final myClaimedProvider = FutureProvider<List<HelpRequest>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const <HelpRequest>[];
  return ref.watch(helpRequestRepositoryProvider).claimedByMe(user.id);
});

/// The signed-in parent's draft (auto-generated, unpublished) requests.
final myDraftsProvider = FutureProvider<List<HelpRequest>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null || !profile.hasVillage) return const <HelpRequest>[];
  return ref
      .watch(helpRequestRepositoryProvider)
      .myDrafts(profile.villageId!, profile.id);
});

/// id -> display name for the current village members (for showing who
/// created/claimed a request).
final memberNameLookupProvider = Provider<Map<String, String>>((ref) {
  final members = ref.watch(villageMembersProvider).value ?? const [];
  return {for (final m in members) m.id: m.displayName};
});

/// Live comment stream for a request.
final requestCommentsProvider =
    StreamProvider.family<List<RequestComment>, String>((ref, requestId) {
  return ref.watch(helpRequestRepositoryProvider).commentsStream(requestId);
});

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepository(ref.watch(supabaseClientProvider));
});

/// Chat threads (active-village requests where you have a counterpart).
final messageThreadsProvider = FutureProvider<List<HelpRequest>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final user = ref.watch(currentUserProvider);
  if (profile == null || !profile.hasVillage || user == null) {
    return const <HelpRequest>[];
  }
  return ref
      .watch(messageRepositoryProvider)
      .threads(profile.villageId!, user.id);
});

/// Live message stream for a request thread.
final messagesStreamProvider =
    StreamProvider.family<List<Message>, String>((ref, requestId) {
  return ref.watch(messageRepositoryProvider).stream(requestId);
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final gpsRepositoryProvider = Provider<GpsRepository>((ref) {
  return GpsRepository(ref.watch(supabaseClientProvider));
});

/// Live breadcrumb trail for a request (parent watches helper position).
final breadcrumbsStreamProvider =
    StreamProvider.family<List<Breadcrumb>, String>((ref, requestId) {
  return ref.watch(gpsRepositoryProvider).stream(requestId);
});

// ---- M7 notifications ------------------------------------------------------
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(supabaseClientProvider));
});

final notificationsStreamProvider =
    StreamProvider<List<AppNotification>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const <AppNotification>[]);
  return ref.watch(notificationRepositoryProvider).stream(user.id);
});

final unreadCountProvider = Provider<int>((ref) {
  final list = ref.watch(notificationsStreamProvider).value ?? const [];
  return list.where((n) => n.isUnread).length;
});

// ---- M8 emergency ----------------------------------------------------------
final emergencyRepositoryProvider = Provider<EmergencyRepository>((ref) {
  return EmergencyRepository(ref.watch(supabaseClientProvider));
});

final emergencyAlertsStreamProvider =
    StreamProvider<List<EmergencyAlert>>((ref) {
  final profile = ref.watch(currentProfileProvider).value;
  if (profile == null || !profile.hasVillage) {
    return Stream.value(const <EmergencyAlert>[]);
  }
  return ref.watch(emergencyRepositoryProvider).stream(profile.villageId!);
});

final activeEmergencyCountProvider = Provider<int>((ref) {
  final list = ref.watch(emergencyAlertsStreamProvider).value ?? const [];
  return list.where((a) => a.isActive).length;
});

// ---- M9 subscriptions ------------------------------------------------------
/// Temporary test-mode override: every signed-in account behaves as premium
/// until subscriptions are re-enabled for public release.
final isPremiumProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

// ---- Direct messages + broadcasts ------------------------------------------
final directMessageRepositoryProvider =
    Provider<DirectMessageRepository>((ref) {
  return DirectMessageRepository(ref.watch(supabaseClientProvider));
});

final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  return AnnouncementRepository(ref.watch(supabaseClientProvider));
});

/// All of the user's direct messages in the active village (one subscription;
/// UI derives conversations + threads from it).
final directMessagesProvider = StreamProvider<List<DirectMessage>>((ref) {
  final profile = ref.watch(currentProfileProvider).value;
  if (profile == null || !profile.hasVillage) {
    return Stream.value(const <DirectMessage>[]);
  }
  return ref.watch(directMessageRepositoryProvider).streamAll(profile.villageId!);
});

/// Unread direct-message count (messages sent to me, not yet read).
final unreadDirectCountProvider = Provider<int>((ref) {
  final me = ref.watch(currentUserProvider)?.id;
  final msgs = ref.watch(directMessagesProvider).value ?? const [];
  return msgs.where((m) => m.recipientId == me && m.readAt == null).length;
});

final announcementsProvider = StreamProvider<List<Announcement>>((ref) {
  final profile = ref.watch(currentProfileProvider).value;
  if (profile == null || !profile.hasVillage) {
    return Stream.value(const <Announcement>[]);
  }
  return ref.watch(announcementRepositoryProvider).stream(profile.villageId!);
});

// ---- Availability + calendar -----------------------------------------------
final availabilityRepositoryProvider = Provider<AvailabilityRepository>((ref) {
  return AvailabilityRepository(ref.watch(supabaseClientProvider));
});

/// The signed-in user's own availability/work blocks.
final myAvailabilityProvider = FutureProvider<List<AvailabilityBlock>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const <AvailabilityBlock>[];
  return ref.watch(availabilityRepositoryProvider).forUser(user.id);
});

/// Everyone's availability/work blocks in the active village (for the calendar).
final villageAvailabilityProvider =
    FutureProvider<List<AvailabilityBlock>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null || !profile.hasVillage) {
    return const <AvailabilityBlock>[];
  }
  return ref.watch(availabilityRepositoryProvider).forVillage(profile.villageId!);
});

/// Non-draft requests for a given week (Monday-anchored) in the active village.
final weekRequestsProvider =
    FutureProvider.family<List<HelpRequest>, DateTime>((ref, weekStart) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null || !profile.hasVillage) return const <HelpRequest>[];
  final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
  final end = start.add(const Duration(days: 7));
  return ref.watch(helpRequestRepositoryProvider).inRange(
        profile.villageId!,
        start.toUtc().toIso8601String(),
        end.toUtc().toIso8601String(),
      );
});

/// The signed-in user's profile (null when signed out).
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.watch(profileRepositoryProvider).fetchProfile(user.id);
});

/// The village the user currently belongs to (null when not in one).
final currentVillageProvider = FutureProvider<Village?>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null || !profile.hasVillage) return null;
  return ref.watch(villageRepositoryProvider).fetchVillage(profile.villageId!);
});

/// Members of the user's ACTIVE village (with their per-village role).
final villageMembersProvider = FutureProvider<List<Profile>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null || !profile.hasVillage) return const <Profile>[];
  final rows = await ref.watch(villageRepositoryProvider).activeVillageMembers();
  return rows.map(Profile.fromMap).toList();
});

/// Every village the user belongs to (for the switcher).
final myVillagesProvider = FutureProvider<List<VillageMembership>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const <VillageMembership>[];
  ref.watch(currentProfileProvider); // refresh when active village changes
  return ref.watch(villageRepositoryProvider).myVillages();
});

/// The user's role IN the active village (per-village, not global).
final activeRoleProvider = Provider<UserRole>((ref) {
  final villages = ref.watch(myVillagesProvider).value ?? const [];
  for (final v in villages) {
    if (v.isActive) return UserRole.fromName(v.role);
  }
  return ref.watch(currentProfileProvider).value?.role ?? UserRole.parent;
});

/// The signed-in user's own pending join request (drives the onboarding
/// "waiting for approval" view).
final myPendingJoinProvider = FutureProvider<PendingJoin?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.watch(villageRepositoryProvider).myPendingJoin();
});

/// Pending join requests for an admin of the ACTIVE village to approve.
final pendingJoinRequestsProvider =
    FutureProvider<List<JoinRequestItem>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final role = ref.watch(activeRoleProvider);
  if (profile == null || !profile.hasVillage || role != UserRole.admin) {
    return const <JoinRequestItem>[];
  }
  return ref.watch(villageRepositoryProvider).pendingJoinRequests();
});

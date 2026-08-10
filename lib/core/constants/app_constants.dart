class AppConstants {
  // Supabase configuration — replace with your actual project credentials
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  // Firebase configuration
  static const String firebaseProjectId = 'shuttleprohero-dev';

  // App metadata
  static const String appName = 'My Village Pro';
  static const String appVersion = '1.0.0';

  // Event status constants
  static const String eventStatusPending = 'pending';
  static const String eventStatusConfirmed = 'confirmed';
  static const String eventStatusInProgress = 'in_progress';
  static const String eventStatusCompleted = 'completed';
  static const String eventStatusCancelled = 'cancelled';
  static const String eventStatusNoShow = 'no_show';

  // Commitment status constants
  static const String commitmentStatusRequested = 'requested';
  static const String commitmentStatusAccepted = 'accepted';
  static const String commitmentStatusDeclined = 'declined';
  static const String commitmentStatusExpired = 'expired';

  // Accountability chain steps
  static const List<String> accountabilitySteps = [
    'commitment_requested',
    'commitment_accepted',
    'details_confirmed',
    'transit_started',
    'in_transit',
    'arrival_confirmed',
    'safe_received',
  ];

  // Notification channels
  static const String notificationChannelCommitments = 'commitments';
  static const String notificationChannelReminders = 'reminders';
  static const String notificationChannelAccountability = 'accountability';

  // Time constants
  static const Duration reminderBeforeEvent = Duration(minutes: 30);
  static const Duration commitmentTimeout = Duration(hours: 24);
  static const Duration noShowThreshold = Duration(minutes: 15);

  // Location tracking
  static const Duration locationUpdateInterval = Duration(seconds: 30);
  static const double locationAccuracyMeters = 10.0;

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxEventsPerDay = 50;
}

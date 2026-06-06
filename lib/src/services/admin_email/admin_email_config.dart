/// Admin web email dispatch (no Cloud Functions / Blaze required).
abstract final class AdminEmailConfig {
  static const String settingsPath = 'admin_settings/email';
  static const String sentMarkersCollection = 'admin_email_sent';
  static const String dispatchLogsCollection = 'email_dispatch_logs';
  static const String adminWebBaseUrl = 'https://neetappadmin.satlas.org/';
  static const String defaultRelayUrl =
      'https://neetappadmin.satlas.org/api/send-email';

  static const defaultTriggers = <String, bool>{
    'userRegistered': true,
    'updatePublished': true,
    'breakingUpdate': true,
    'demoRequestCreated': true,
    'analysisSessionStatusChanged': true,
    'courseInquiryCreated': true,
    'courseDemoBooked': true,
    'messageReceived': true,
    'collegeAlertUpdate': true,
    'subscriptionPurchase': true,
    'accountDeletionRequested': true,
    'accountDeletionCompleted': true,
    'accountDeletionRejected': true,
  };
}

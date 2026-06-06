/// Renders email subject/HTML from admin_settings templates (same keys as legacy Functions).
abstract final class AdminEmailTemplates {
  static String render(String template, Map<String, String> payload) {
    return template.replaceAllMapped(RegExp(r'\{([a-zA-Z0-9_]+)\}'), (match) {
      final key = match.group(1);
      if (key == null || !payload.containsKey(key)) return match.group(0)!;
      return _escapeHtml(payload[key] ?? '');
    });
  }

  static String defaultSubject(String triggerKey, String audience) {
    final isAdmin = audience == 'admin';
    switch (triggerKey) {
      case 'userRegistered':
        return isAdmin
            ? 'New app user registered: {userName}'
            : 'Welcome to {appName}';
      case 'updatePublished':
        return isAdmin
            ? 'NEET Pulse update published: {updateTitle}'
            : '{updateTitle}';
      case 'breakingUpdate':
        return isAdmin
            ? 'Breaking NEET alert sent: {updateTitle}'
            : 'Important NEET update: {updateTitle}';
      case 'demoRequestCreated':
        return isAdmin
            ? 'New expected score demo request from {studentName}'
            : 'We received your demo request';
      case 'analysisSessionStatusChanged':
        return isAdmin
            ? 'Analysis session status changed for {studentName}'
            : 'Your analysis session is {status}';
      case 'courseInquiryCreated':
        return isAdmin
            ? 'New course inquiry: {courseName}'
            : 'Thanks for contacting TestprepKart';
      case 'courseDemoBooked':
        return isAdmin
            ? 'New course demo booking: {courseName}'
            : 'Your course demo request is confirmed';
      case 'messageReceived':
        return isAdmin
            ? 'New user message: {messageTopic}'
            : 'We received your message';
      case 'collegeAlertUpdate':
        return isAdmin
            ? 'College alert update sent: {collegeName}'
            : 'Update for {collegeName}';
      case 'subscriptionPurchase':
        return isAdmin
            ? 'Subscription purchase by {userName}'
            : 'Your TestprepKart subscription is active';
      case 'accountDeletionRequested':
        return isAdmin
            ? 'Account deletion requested: {email}'
            : 'We received your account deletion request';
      case 'accountDeletionCompleted':
        return 'Your TestprepKart account has been deleted';
      case 'accountDeletionRejected':
        return 'Update on your account deletion request';
      default:
        return isAdmin
            ? 'Admin notification from {appName}'
            : 'Notification from {appName}';
    }
  }

  static String defaultHtml(String triggerKey, String audience) {
    final isAdmin = audience == 'admin';
    final greeting = isAdmin ? 'Hello Admin,' : 'Hello {userName},';
    final ctaLabel = isAdmin ? 'Open Admin Panel' : 'Open TestprepKart';
    final body = _body(triggerKey, audience);
    return '''
<!doctype html>
<html>
  <body style="margin:0;background:#f6f7fb;font-family:Arial,Helvetica,sans-serif;color:#111827;">
    <table width="100%" cellpadding="0" cellspacing="0" role="presentation" style="background:#f6f7fb;padding:24px 0;">
      <tr><td align="center">
        <table width="600" cellpadding="0" cellspacing="0" role="presentation" style="max-width:600px;width:100%;background:#ffffff;border-radius:16px;overflow:hidden;border:1px solid #e5e7eb;">
          <tr><td style="background:#4f46e5;padding:18px 24px;color:#ffffff;font-size:20px;font-weight:700;">{appName}</td></tr>
          <tr><td style="padding:28px 24px;">
            <p style="margin:0 0 16px;font-size:16px;line-height:1.5;">$greeting</p>
            $body
            <p style="margin:24px 0 0;"><a href="{actionUrl}" style="display:inline-block;background:#4f46e5;color:#ffffff;text-decoration:none;padding:12px 18px;border-radius:10px;font-size:14px;font-weight:700;">$ctaLabel</a></p>
          </td></tr>
          <tr><td style="padding:16px 24px;background:#f9fafb;color:#6b7280;font-size:12px;">This email was sent by {appName}.</td></tr>
        </table>
      </td></tr>
    </table>
  </body>
</html>''';
  }

  static String _body(String triggerKey, String audience) {
    final isAdmin = audience == 'admin';
    switch (triggerKey) {
      case 'userRegistered':
        return isAdmin
            ? '<p style="margin:0;font-size:15px;line-height:1.6;"><strong>{userName}</strong> ({email}) registered in the app.</p>'
            : '<p style="margin:0;font-size:15px;line-height:1.6;">Welcome to TestprepKart NEET Prep. Your account is ready — sign in anytime to continue your admission journey.</p>';
      case 'updatePublished':
        return isAdmin
            ? '<p style="margin:0;font-size:15px;line-height:1.6;">Update published: <strong>{updateTitle}</strong></p>'
            : '<p style="margin:0;font-size:15px;line-height:1.6;">New update: <strong>{updateTitle}</strong></p>';
      case 'breakingUpdate':
        return isAdmin
            ? '<p style="margin:0;font-size:15px;line-height:1.6;">Breaking update: <strong>{updateTitle}</strong></p>'
            : '<p style="margin:0;font-size:15px;line-height:1.6;">Important: <strong>{updateTitle}</strong></p>';
      case 'demoRequestCreated':
        return isAdmin
            ? '<p style="margin:0;font-size:15px;line-height:1.6;">Demo request from <strong>{studentName}</strong> ({email})</p>'
            : '<p style="margin:0;font-size:15px;line-height:1.6;">We received your demo request and will confirm shortly.</p>';
      case 'analysisSessionStatusChanged':
        return isAdmin
            ? '<p style="margin:0;font-size:15px;line-height:1.6;">Session for <strong>{studentName}</strong> → <strong>{status}</strong> ({sessionDate} {sessionTime})</p>'
            : '<p style="margin:0;font-size:15px;line-height:1.6;">Your session status is <strong>{status}</strong>. Schedule: {sessionDate} {sessionTime}</p>';
      case 'courseInquiryCreated':
        return isAdmin
            ? '<p style="margin:0;font-size:15px;line-height:1.6;">Inquiry for <strong>{courseName}</strong> from {studentName}</p>'
            : '<p style="margin:0;font-size:15px;line-height:1.6;">Thanks for your interest in <strong>{courseName}</strong>.</p>';
      case 'courseDemoBooked':
        return isAdmin
            ? '<p style="margin:0;font-size:15px;line-height:1.6;">Demo booked: <strong>{courseName}</strong></p>'
            : '<p style="margin:0;font-size:15px;line-height:1.6;">Your demo for <strong>{courseName}</strong> is recorded.</p>';
      case 'messageReceived':
        return isAdmin
            ? '<p style="margin:0;font-size:15px;line-height:1.6;">Topic: <strong>{messageTopic}</strong><br>{messageContent}</p>'
            : '<p style="margin:0;font-size:15px;line-height:1.6;">We received your message about <strong>{messageTopic}</strong>.</p>';
      case 'collegeAlertUpdate':
        return isAdmin
            ? '<p style="margin:0;font-size:15px;line-height:1.6;">College alert: <strong>{collegeName}</strong></p>'
            : '<p style="margin:0;font-size:15px;line-height:1.6;">Update for <strong>{collegeName}</strong></p>';
      case 'subscriptionPurchase':
        return isAdmin
            ? '<p style="margin:0;font-size:15px;line-height:1.6;">{userName} upgraded ({amount})</p>'
            : '<p style="margin:0;font-size:15px;line-height:1.6;">Your subscription is active. Thank you!</p>';
      case 'accountDeletionRequested':
        return isAdmin
            ? '<p style="margin:0;font-size:15px;line-height:1.6;">Deletion requested for <strong>{email}</strong>. Review in Admin → Unsubscribe.</p>'
            : '<p style="margin:0;font-size:15px;line-height:1.6;">We received your request to delete your TestprepKart NEET app account ({email}). Our team will verify and process it within 30 days. You will receive another email when deletion is completed or if we need to cancel the request.</p>';
      case 'accountDeletionCompleted':
        return '<p style="margin:0;font-size:15px;line-height:1.6;">Your account deletion request has been completed. Your app account and associated personal data have been removed or anonymized as described on our deletion page. If you did not request this, contact support@testprepkart.com immediately.</p>';
      case 'accountDeletionRejected':
        return '<p style="margin:0;font-size:15px;line-height:1.6;">We could not complete your account deletion request at this time (for example pending subscription, open counseling case, or identity verification). Your account remains active. Contact support@testprepkart.com if you have questions.</p>';
      default:
        return '<p style="margin:0;font-size:15px;line-height:1.6;">You have a new notification.</p>';
    }
  }

  static String _escapeHtml(String raw) {
    return raw
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}

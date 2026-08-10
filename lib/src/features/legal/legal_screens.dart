import 'package:flutter/material.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ),
    );
  }
}

const String kTermsText = '''
My Village Pro — Terms of Service

These are placeholder terms for the preview release. Replace with your
finalized Terms of Service before launch.

1. Acceptance. By using My Village Pro you agree to coordinate childcare and
   help requests responsibly with people in your trusted village.

2. Your responsibilities. You are responsible for vetting the people you add to
   your village. My Village Pro helps coordinate care among people you already
   know and trust; it does not screen, background-check, or vouch for members.

3. Acceptable use. Do not use the app to harass, endanger, or mislead other
   members. Emergency alerts are for genuine emergencies.

4. Location data. When you choose to share live location during a trip, it is
   visible to the requesting parent and retained for up to 7 days.

5. No warranty. The service is provided "as is" during this preview.

Contact: support@yourdomain.example
''';

const String kPrivacyText = '''
My Village Pro — Privacy Policy

This is a placeholder privacy policy for the preview release. Replace with your
finalized policy before launch.

What we store: your profile (name, email, role), your villages and memberships,
kid profiles you create, help requests, messages, and—only while you actively
share it—trip location breadcrumbs (auto-deleted after 7 days).

Who can see it: data is isolated per village. Members only see data in the
village they are actively viewing. Kid profile details are visible only to the
parent who created them (and, where applicable, that village's admin).

Your choices: you control whether to share live location, and you can leave a
village at any time. You can request deletion of your account and data.

Contact: privacy@yourdomain.example
''';

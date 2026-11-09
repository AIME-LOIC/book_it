import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum LegalDocument { terms, privacy }

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.document});

  final LegalDocument document;

  bool get _isTerms => document == LegalDocument.terms;
  String get _title => _isTerms ? 'Terms of Service' : 'Privacy Policy';

  List<_LegalSection> get _sections => _isTerms
      ? const [
          _LegalSection('1. About BookIt', 'BookIt is a bus-booking service operated under the 1percent Rwanda name in Rwanda. These terms explain the rules for using the BookIt application and related booking services.'),
          _LegalSection('2. Acceptance and eligibility', 'By creating an account or using BookIt, you agree to these terms. You must provide accurate account information and keep your sign-in credentials secure. If you do not agree, do not use the service.'),
          _LegalSection('3. Accounts and security', 'You are responsible for activity carried out through your account. Notify BookIt support promptly if you suspect unauthorized access. We may restrict access where necessary to protect users, operators, or the service.'),
          _LegalSection('4. Booking and payment', 'A booking is confirmed only when BookIt displays a confirmed ticket. Check the route, travel date, departure details, passenger information, and fare before completing payment. Payment processing may be provided by third-party payment providers and is subject to their terms.'),
          _LegalSection('5. Tickets and travel', 'Keep your ticket and QR code available when boarding. A ticket is valid only for the journey and passenger details shown on it. Bus operators are responsible for operating the service and carrying out boarding checks.'),
          _LegalSection('6. Cancellations and refunds', 'Cancellation, change, and refund eligibility may depend on the operator, ticket conditions, and applicable law. Any conditions shown during booking or on your ticket apply to that booking. Contact support with your booking reference if you need assistance.'),
          _LegalSection('7. Acceptable use', 'Do not misuse BookIt, interfere with its operation, attempt unauthorized access, submit false information, or use another person’s account or payment details without permission.'),
          _LegalSection('8. Service availability', 'We work to keep BookIt available and accurate, but access may occasionally be interrupted for maintenance, connectivity, or circumstances outside our control. App features may change as the service develops.'),
          _LegalSection('9. Liability', 'To the extent permitted by Rwandan law, 1percent Rwanda is not responsible for indirect loss arising from interruptions or third-party services. Nothing in these terms excludes liability that cannot legally be excluded.'),
          _LegalSection('10. Changes and contact', 'We may update these terms when the service or applicable requirements change. The latest version will be made available in the app. For questions or complaints, contact 1percent Rwanda through the support channel provided in BookIt.'),
        ]
      : const [
          _LegalSection('1. Scope', 'This policy explains how BookIt and 1percent Rwanda handle personal information when you use the BookIt app and related bus-booking services.'),
          _LegalSection('2. Information we may collect', 'Depending on how you use BookIt, information may include your name, email address, phone number, account identifier, booking and ticket details, payment references, device and notification tokens, and information you send to support.'),
          _LegalSection('3. How information is used', 'We use information to create and secure accounts, search and manage bookings, issue and validate tickets, process payment workflows, send service and booking notifications, provide customer support, prevent misuse, and improve BookIt.'),
          _LegalSection('4. Sharing', 'We do not sell personal information. Information may be shared with bus operators to fulfil a booking, payment providers to process transactions, infrastructure and messaging providers that help operate BookIt, or authorities where disclosure is required by law.'),
          _LegalSection('5. Storage and security', 'We use access controls and reasonable technical and organizational safeguards to protect information. Information may be processed by service providers in locations outside Rwanda. No internet transmission or storage system can be guaranteed completely secure.'),
          _LegalSection('6. Retention', 'We retain information for as long as needed to provide the service, maintain booking and financial records, resolve disputes, meet legal obligations, and protect the platform. Retention periods depend on the type of information and applicable requirements.'),
          _LegalSection('7. Your choices and rights', 'You may request access to or correction of personal information associated with your account, and may ask about deletion where applicable. Some records may need to be retained to complete bookings, meet legal duties, or resolve disputes.'),
          _LegalSection('8. Notifications and location', 'If you grant permission, BookIt may send push notifications about bookings, account activity, and service updates. Location information is used only where a feature requires it and the relevant permission is granted. You can manage app permissions in your device settings.'),
          _LegalSection('9. Children', 'BookIt is intended for people able to enter into a booking agreement. A parent or guardian should assist a minor where required by law or operator policy.'),
          _LegalSection('10. Policy updates and contact', 'We may revise this policy as BookIt changes. The current version will be available in the app. For privacy questions or requests, contact 1percent Rwanda through the BookIt support channel.'),
        ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title, style: const TextStyle(fontWeight: FontWeight.w800))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_isTerms ? Icons.description_outlined : Icons.privacy_tip_outlined, color: AppColors.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 5),
                      const Text('BookIt • 1percent Rwanda', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      const SizedBox(height: 8),
                      Text(_isTerms ? 'Please read the rules for using BookIt.' : 'Learn what information BookIt uses and how it is handled.', style: const TextStyle(fontSize: 13, height: 1.45)),
                    ]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            for (final section in _sections) ...[
              Text(section.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 7),
              Text(section.body, style: TextStyle(fontSize: 14, height: 1.6, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegalSection {
  const _LegalSection(this.title, this.body);
  final String title;
  final String body;
}

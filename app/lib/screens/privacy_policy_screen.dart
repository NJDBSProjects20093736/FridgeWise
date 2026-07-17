import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// In-app Privacy Policy (same content as docs/privacy-policy.html).
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const publicUrl =
      'https://cdn.jsdelivr.net/gh/NJDBSProjects20093736/FridgeWise@Thrifty-chef-implementations/docs/privacy-policy.html';

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppTheme.textMuted,
          height: 1.45,
        );
    final titleStyle = Theme.of(context).textTheme.titleMedium;

    Widget section(String title, List<Widget> children) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: titleStyle),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: AppTheme.pagePadding(context),
        children: [
          Text('ThriftyChef Privacy Policy', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Last updated: 16 July 2026\n'
            'Academic prototype — Dublin Business School, MSc Artificial Intelligence.',
            style: bodyStyle,
          ),
          const SizedBox(height: 16),
          Text(
            'ThriftyChef helps users reduce food waste by tracking fridge ingredients and recommending recipes. '
            'This policy explains what information the App collects and how it is used.',
            style: bodyStyle,
          ),
          const SizedBox(height: 18),
          section('1. Who we are', [
            Text(
              'ThriftyChef is a student/academic prototype. For privacy questions, contact the developer via the project GitHub Issues page.',
              style: bodyStyle,
            ),
          ]),
          section('2. Information we collect', [
            Text(
              '• Profile preferences (diet, allergies, cuisine, nutrition)\n'
              '• Fridge and shopping data (ingredients, expiry, lists)\n'
              '• In-app usage needed for recommendations (recipe views, plans, ratings)\n'
              '• Camera access only if you choose barcode scanning (frames are not saved as a photo library)\n'
              '• Local preferences such as theme mode\n\n'
              'The demo experience may use a shared demo profile. Avoid entering sensitive personal data you do not want in a prototype system.',
              style: bodyStyle,
            ),
          ]),
          section('3. How we use information', [
            Text(
              'We use this information to generate recommendations, apply allergy/diet safety filters, prioritise expiring food, support barcode lookup and meal planning, and operate this academic prototype. We do not sell personal information.',
              style: bodyStyle,
            ),
          ]),
          section('4. Where information is stored', [
            Text(
              'Some data is stored on your device. If connected to the ThriftyChef API/database for your deployment, profile and fridge-related data may be sent to that backend to power recommendations.',
              style: bodyStyle,
            ),
          ]),
          section('5. Third-party content', [
            Text(
              'The App may show recipe catalogues, product/barcode metadata, nutrition or shelf-life reference data, and image URLs from third-party sources needed for App features.',
              style: bodyStyle,
            ),
          ]),
          section('6. Your choices', [
            Text(
              'You can edit profile and fridge data in the App, deny camera permission and type barcodes manually, and clear local app data by uninstalling the App or clearing app storage.',
              style: bodyStyle,
            ),
          ]),
          section('7. Children', [
            Text(
              'The App is not directed at children under 13 (or the equivalent minimum age in your region).',
              style: bodyStyle,
            ),
          ]),
          section('8. Contact', [
            Text(
              'GitHub Issues: https://github.com/NJDBSProjects20093736/FridgeWise/issues\n\n'
              'Public Privacy Policy URL:\n$publicUrl',
              style: bodyStyle,
            ),
          ]),
        ],
      ),
    );
  }
}

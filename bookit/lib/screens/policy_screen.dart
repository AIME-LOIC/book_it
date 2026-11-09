import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/app_theme.dart';

class PolicyScreen extends StatefulWidget {
  const PolicyScreen({super.key});

  @override
  State<PolicyScreen> createState() => _PolicyScreenState();
}

class _PolicyScreenState extends State<PolicyScreen> {
  static final Uri _policyUrl = Uri.parse('https://bookit.1percent.rw/policy.html');
  late final bool _supportsWebView = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  late final WebViewController _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.disabled)
    ..setNavigationDelegate(NavigationDelegate(
      onWebResourceError: (_) {
        if (mounted) setState(() {});
      },
    ))
    ..loadRequest(_policyUrl);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Privacy')),
      body: _supportsWebView
          ? WebViewWidget(controller: _controller)
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.policy_outlined, size: 48, color: AppColors.primary),
                  const SizedBox(height: 14),
                  const Text('BookIt Terms of Service and Privacy Policy', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  const SizedBox(height: 8),
                  const Text('Open the current policy in your browser.', textAlign: TextAlign.center),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () => launchUrl(_policyUrl, mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text('Open policy'),
                  ),
                ]),
              ),
            ),
    );
  }
}

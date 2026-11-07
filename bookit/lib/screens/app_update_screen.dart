import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_update_service.dart';
import '../theme/app_theme.dart';

class AppUpdateScreen extends StatefulWidget {
  const AppUpdateScreen({super.key});

  @override
  State<AppUpdateScreen> createState() => _AppUpdateScreenState();
}

class _AppUpdateScreenState extends State<AppUpdateScreen> {
  AppUpdate? _update;
  String _currentVersion = '—';
  bool _checking = true;
  bool _installing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() { _checking = true; _error = null; });
    try {
      final info = await PackageInfo.fromPlatform();
      final update = await AppUpdateService.checkForUpdate();
      if (!mounted) return;
      setState(() {
        _currentVersion = info.version;
        _update = update;
        _checking = false;
      });
    } catch (_) {
      if (mounted) setState(() { _checking = false; _error = 'Could not check for updates. Please try again.'; });
    }
  }

  Future<void> _installUpdate() async {
    final update = _update;
    if (update == null || !update.hasPlatformAsset) return;
    setState(() => _installing = true);

    if (!kIsWeb && Platform.isLinux) {
      final started = await AppUpdateService.runLinuxUpdater();
      if (!started && mounted) {
        setState(() => _installing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start the BookIt updater. Please try again.')),
        );
      }
      return;
    }

    final url = update.downloadUrl;
    if (url == null) {
      if (mounted) setState(() => _installing = false);
      return;
    }
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    setState(() => _installing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(opened
          ? 'The APK download has started. Android will ask you to approve installation.'
          : 'Could not open the update download. Please try again.'),
    ));
  }

  Future<void> _openReleaseDetails() async {
    final url = _update?.releaseUrl;
    if (url != null) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final update = _update;
    final linux = !kIsWeb && Platform.isLinux;
    return Scaffold(
      appBar: AppBar(title: const Text('App updates')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  Icon(_checking ? Icons.sync_rounded : update == null ? Icons.verified_rounded : Icons.system_update_alt_rounded,
                    size: 54, color: AppColors.primary),
                  const SizedBox(height: 14),
                  Text(_checking ? 'Checking BookIt' : update == null ? 'You are up to date' : 'A new version is ready',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('Installed version: $_currentVersion', style: Theme.of(context).textTheme.bodyMedium),
                  if (update != null) ...[
                    const SizedBox(height: 4),
                    Text('Available version: ${update.version}',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                  ],
                ],
              ),
            ),
            if (_checking || _installing) ...[
              const SizedBox(height: 22),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(_installing ? 'Preparing the BookIt update…' : 'Checking the latest release…',
                textAlign: TextAlign.center),
            ],
            if (_error != null) Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
            if (update != null) ...[
              const SizedBox(height: 22),
              Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('What’s new', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Text(update.notes, style: Theme.of(context).textTheme.bodyMedium),
                ]),
              )),
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: _installing || !update.hasPlatformAsset ? null : _installUpdate,
                icon: _installing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(linux ? Icons.system_update_alt_rounded : Icons.download_rounded),
                label: Text(_installing
                    ? 'Preparing update…'
                    : !update.hasPlatformAsset
                        ? 'No update package for this device'
                        : linux ? 'Install update and restart' : 'Download and install update'),
              )),
              const SizedBox(height: 8),
              Text(
                linux
                    ? 'BookIt will download and verify the update, then restart using the new version. No terminal commands are needed.'
                    : 'BookIt will download the APK. Android will ask you to confirm installation; Android does not allow ordinary apps to install APKs silently.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _openReleaseDetails,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('View full release details'),
              ),
            ],
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _checking || _installing ? null : _check,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Check again'),
            ),
            if (kIsWeb) const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Web updates are applied when the website is redeployed.'),
            ),
          ],
        ),
      ),
    );
  }
}

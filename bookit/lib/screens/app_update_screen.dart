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
  bool _openingDownload = false;
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

  Future<void> _startUpdate() async {
    final update = _update;
    if (update == null) return;
    setState(() => _openingDownload = true);
    final opened = await launchUrl(update.downloadUrl, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    setState(() => _openingDownload = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(opened
          ? 'Download opened. Complete the installation, then reopen BookIt.'
          : 'Could not open the download. Try the release page instead.'),
      action: opened ? null : SnackBarAction(
        label: 'Release page',
        onPressed: () => launchUrl(update.releaseUrl, mode: LaunchMode.externalApplication),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final update = _update;
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
                  Text('Installed version: $_currentVersion',
                    style: Theme.of(context).textTheme.bodyMedium),
                  if (update != null) ...[
                    const SizedBox(height: 4),
                    Text('Available version: ${update.version}',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                  ],
                ],
              ),
            ),
            if (_checking || _openingDownload) ...[
              const SizedBox(height: 22),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(_openingDownload ? 'Opening the official download…' : 'Checking the latest release…',
                textAlign: TextAlign.center),
            ],
            if (_error != null) Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
            if (update != null) ...[
              const SizedBox(height: 22),
              if (update.notes.trim().isNotEmpty)
                Card(child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('What’s new', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(update.notes, maxLines: 12, overflow: TextOverflow.ellipsis),
                  ]),
                )),
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: _openingDownload ? null : _startUpdate,
                icon: _openingDownload
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download_rounded),
                label: Text(_openingDownload ? 'Opening download…' : 'Download update'),
              )),
              const SizedBox(height: 8),
              const Text('BookIt will open the official release download. Your device will ask you to confirm installation; the app cannot silently install itself.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
            ],
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _checking ? null : _check,
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

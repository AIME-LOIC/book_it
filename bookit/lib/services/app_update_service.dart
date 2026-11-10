import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.releaseUrl,
    required this.notes,
    this.downloadUrl,
    this.hasPlatformAsset = false,
  });

  final String version;
  final Uri releaseUrl;
  final Uri? downloadUrl;
  final String notes;
  final bool hasPlatformAsset;
}

class AppUpdateService {
  AppUpdateService._();

  static const _repo = 'AIME-LOIC/book_it';
  static const _skippedVersionKey = 'bookit_skipped_update_version';

  static Future<AppUpdate?> checkForUpdate({bool ignoreSkipped = false}) async {
    try {
      final info = await PackageInfo.fromPlatform();
      // A tag can appear before its build finishes. Walk recent published
      // releases and select the newest one that actually contains this
      // device's installable package, rather than treating an empty release
      // as the latest usable update.
      final response = await http.get(
        Uri.https('api.github.com', '/repos/$_repo/releases', {'per_page': '10'}),
        headers: const {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          'Cache-Control': 'no-cache, no-store',
          'Pragma': 'no-cache',
        },
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! List) return null;

      final prefs = await SharedPreferences.getInstance();
      for (final entry in decoded) {
        if (entry is! Map<String, dynamic> ||
            entry['draft'] == true ||
            entry['prerelease'] == true) continue;
        final tag = (entry['tag_name'] ?? '').toString()
            .replaceFirst(RegExp(r'^[vV]'), '');
        if (tag.isEmpty || !_isNewer(tag, info.version)) continue;
        if (!ignoreSkipped && prefs.getString(_skippedVersionKey) == tag) continue;

        final assets = (entry['assets'] is List ? entry['assets'] as List : const [])
            .whereType<Map>()
            .toList();
        final asset = _assetForPlatform(assets);
        final rawDownloadUrl = (asset?['browser_download_url'] ?? '').toString();
        final downloadUri = Uri.tryParse(rawDownloadUrl);
        if (downloadUri == null ||
            downloadUri.scheme != 'https' ||
            downloadUri.host != 'github.com') continue;

        final rawReleaseUrl = (entry['html_url'] ?? '').toString();
        final releaseUri = Uri.tryParse(rawReleaseUrl);
        final releaseUrl = releaseUri != null && releaseUri.scheme == 'https'
            ? releaseUri
            : Uri.https('github.com', '$_repo/releases/tag/v$tag');
        final notes = await _fetchPlainTextNotes(tag, (entry['body'] ?? '').toString());

        return AppUpdate(
          version: tag,
          releaseUrl: releaseUrl,
          downloadUrl: downloadUri,
          hasPlatformAsset: true,
          notes: notes,
        );
      }
      return null;
    } catch (_) {
      // An update check must never prevent a passenger from opening BookIt.
      return null;
    }
  }

  static Future<String> _fetchPlainTextNotes(String version, String releaseBody) async {
    try {
      final response = await http.get(
        Uri.parse('https://raw.githubusercontent.com/$_repo/main/bookit/whats_new.txt'),
        headers: const {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final content = response.body.trim();
        final firstLine = content.split(RegExp(r'\r?\n')).first.trim();
        final publishedVersion = firstLine.replaceFirst(RegExp(r'^BookIt\s+', caseSensitive: false), '').trim();
        if (publishedVersion == version && content.isNotEmpty) {
          return _cleanReleaseNotes(content.split(RegExp(r'\r?\n')).skip(1).join('\n'));
        }
      }
    } catch (_) {
      // Fall back to release metadata if the plain-text notes endpoint is unavailable.
    }
    return _cleanReleaseNotes(releaseBody);
  }

  static String _cleanReleaseNotes(String raw) {
    final value = raw
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAllMapped(
          RegExp(r'\[([^\]]+)\]\((https?://[^)]+)\)'),
          (match) => match[1] ?? '',
        )
        .replaceAll(RegExp(r'https?://\S+', caseSensitive: false), '')
        .replaceAll(RegExp(r'(?m)^\s*#{1,6}\s*'), '')
        .replaceAll(RegExp(r'(?m)^\s*[-*+]\s+'), '• ')
        .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1')
        .replaceAll(RegExp(r'__(.*?)__'), r'$1')
        .replaceAll(RegExp(r'\*(.*?)\*'), r'$1')
        .replaceAll(RegExp(r'_(.*?)_'), r'$1');

    final lines = value
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where((line) => !RegExp(
              r'^(full )?changelog\s*:?$',
              caseSensitive: false,
            ).hasMatch(line))
        .toList();

    final cleaned = lines.join('\n').trim();
    if (cleaned.isEmpty) {
      return 'Release notes were not provided for this version.';
    }
    return cleaned.length > 1400
        ? '${cleaned.substring(0, 1397)}…'
        : cleaned;
  }

  static Map? _assetForPlatform(List<Map> assets) {
    final names = assets.map((a) => (a['name'] ?? '').toString().toLowerCase()).toList();
    String? wanted;
    if (!kIsWeb && Platform.isAndroid) {
      final index = names.indexWhere((n) => n.endsWith('.apk'));
      if (index >= 0) wanted = assets[index]['name']?.toString();
    } else if (!kIsWeb && Platform.isLinux) {
      final index = names.indexWhere((n) => n.contains('linux') && n.endsWith('.tar.gz'));
      if (index >= 0) wanted = assets[index]['name']?.toString();
    } else if (!kIsWeb && Platform.isIOS) {
      final index = names.indexWhere((n) => n.endsWith('.ipa'));
      if (index >= 0) wanted = assets[index]['name']?.toString();
    }
    if (wanted == null) return null;
    return assets.firstWhere((a) => a['name'] == wanted, orElse: () => {});
  }

  static bool get supportsInAppLinuxUpdate => !kIsWeb && Platform.isLinux;

  static Future<bool> runLinuxUpdater() async {
    if (!supportsInAppLinuxUpdate) return false;
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) return false;
    final appDir = Directory('$home/.local/opt/bookit');
    final scriptFile = File('${appDir.path}/update-linux.sh');
    try {
      await appDir.create(recursive: true);
      if (!await scriptFile.exists()) {
        final response = await http.get(Uri.parse(
          'https://raw.githubusercontent.com/AIME-LOIC/book_it/main/bookit/scripts/update-linux.sh',
        )).timeout(const Duration(seconds: 20));
        if (response.statusCode != 200 || response.body.isEmpty) return false;
        await scriptFile.writeAsString(response.body, flush: true);
      }
      await Process.run('chmod', ['0755', scriptFile.path]);
      await Process.start('/bin/bash', [scriptFile.path], mode: ProcessStartMode.detached);
      // The updater atomically switches the installed release after this app exits.
      exit(0);
    } catch (_) {
      return false;
    }
  }

  static bool _isNewer(String remote, String current) {
    List<int> parts(String value) => value.split('+').first.split('.')
        .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();
    final a = parts(remote), b = parts(current);
    for (var i = 0; i < (a.length > b.length ? a.length : b.length); i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  static Future<void> showUpdatePrompt(BuildContext context, AppUpdate update) async {
    if (!context.mounted) return;
    final later = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.system_update_alt_rounded, size: 34),
        title: const Text('A BookIt update is available'),
        content: Text('Version ${update.version} is ready. Update BookIt to get the latest improvements and fixes.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Later')),
          FilledButton.icon(
            onPressed: update.hasPlatformAsset ? () async {
              if (supportsInAppLinuxUpdate) {
                await runLinuxUpdater();
              } else if (update.downloadUrl != null) {
                await launchUrl(update.downloadUrl!, mode: LaunchMode.externalApplication);
              }
              if (dialogContext.mounted) Navigator.of(dialogContext).pop(false);
            } : null,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Update now'),
          ),
        ],
      ),
    );
    if (later == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_skippedVersionKey, update.version);
    }
  }
}

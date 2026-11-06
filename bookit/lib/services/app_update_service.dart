import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

class AppUpdate {
  const AppUpdate({required this.version, required this.releaseUrl, required this.downloadUrl, this.notes = ''});
  final String version;
  final Uri releaseUrl;
  final Uri downloadUrl;
  final String notes;
}

class AppUpdateService {
  AppUpdateService._();

  static const _repo = 'AIME-LOIC/book_it';
  static const _skippedVersionKey = 'bookit_skipped_update_version';

  static Future<AppUpdate?> checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final response = await http.get(
        Uri.https('api.github.com', '/repos/$_repo/releases/latest'),
        headers: const {'Accept': 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28'},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final release = jsonDecode(response.body);
      if (release is! Map<String, dynamic> || release['draft'] == true || release['prerelease'] == true) return null;
      final tag = (release['tag_name'] ?? '').toString().replaceFirst(RegExp(r'^[vV]'), '');
      if (tag.isEmpty || !_isNewer(tag, info.version)) return null;
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_skippedVersionKey) == tag) return null;
      final releaseUrl = Uri.tryParse((release['html_url'] ?? '').toString());
      if (releaseUrl == null || !releaseUrl.hasScheme) return null;
      final assets = (release['assets'] is List ? release['assets'] as List : const [])
          .whereType<Map>()
          .toList();
      final asset = _assetForPlatform(assets);
      final downloadUrl = Uri.tryParse((asset?['browser_download_url'] ?? releaseUrl.toString()).toString()) ?? releaseUrl;
      return AppUpdate(
        version: tag,
        releaseUrl: releaseUrl,
        downloadUrl: downloadUrl,
        notes: (release['body'] ?? '').toString(),
      );
    } catch (_) {
      // Update checks must never prevent a passenger from opening BookIt.
      return null;
    }
  }

  static Map? _assetForPlatform(List<Map> assets) {
    final names = assets.map((a) => (a['name'] ?? '').toString()).toList();
    String? wanted;
    if (!kIsWeb && Platform.isAndroid) {
      wanted = names.cast<String?>().firstWhere((n) => n != null && n.toLowerCase().endsWith('.apk'), orElse: () => null);
    } else if (!kIsWeb && Platform.isLinux) {
      wanted = names.cast<String?>().firstWhere((n) => n != null && n.toLowerCase().contains('linux') && n.toLowerCase().endsWith('.tar.gz'), orElse: () => null);
    } else if (!kIsWeb && Platform.isIOS) {
      wanted = names.cast<String?>().firstWhere((n) => n != null && n.toLowerCase().endsWith('.ipa'), orElse: () => null);
    }
    if (wanted == null) return null;
    return assets.firstWhere((a) => a['name'] == wanted, orElse: () => {});
  }

  static bool _isNewer(String remote, String current) {
    List<int> parts(String value) => value.split('+').first.split('.').map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();
    final a = parts(remote), b = parts(current);
    for (var i = 0; i < (a.length > b.length ? a.length : b.length); i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  static Future<void> showUpdatePrompt(BuildContext context, AppUpdate update) async {
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
            onPressed: () async {
              await launchUrl(update.downloadUrl, mode: LaunchMode.externalApplication);
              if (dialogContext.mounted) Navigator.of(dialogContext).pop(false);
            },
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

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Read-only GitHub Release checker. Configure the public repository at build
/// time, e.g. --dart-define=RANGEBUDDY_GITHUB_REPOSITORY=owner/RangeBuddy.
class GitHubReleaseService {
  static const installedVersion = String.fromEnvironment(
    'RANGEBUDDY_APP_VERSION',
    defaultValue: '0.1.21',
  );
  static const repository = String.fromEnvironment(
    'RANGEBUDDY_GITHUB_REPOSITORY',
    defaultValue: 'MAD-Script/RangeBuddy',
  );

  Future<GitHubRelease?> latestRelease() async {
    if (repository.isEmpty) return null;
    final response = await http.get(
      Uri.parse('https://api.github.com/repos/$repository/releases/latest'),
      headers: const {'Accept': 'application/vnd.github+json'},
    );
    if (response.statusCode != 200) {
      throw StateError('GitHub returned ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final assets = (data['assets'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final apkAsset = assets.cast<Map<String, dynamic>?>().firstWhere(
          (asset) => (asset?['name'] as String? ?? '').endsWith('.apk'),
          orElse: () => null,
        );
    final checksumAsset = assets.cast<Map<String, dynamic>?>().firstWhere(
          (asset) => (asset?['name'] as String? ?? '').endsWith('.apk.sha256'),
          orElse: () => null,
        );
    return GitHubRelease(
      version: (data['tag_name'] as String? ?? '').replaceFirst('v', ''),
      notes: data['body'] as String? ?? 'No release notes provided.',
      pageUrl: data['html_url'] as String? ?? '',
      apkUrl: apkAsset?['browser_download_url'] as String?,
      checksumUrl: checksumAsset?['browser_download_url'] as String?,
    );
  }
}

class AndroidUpdateInstaller {
  static const _channel = MethodChannel('rangebuddy/update');

  Future<void> downloadAndInstall(GitHubRelease release) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('APK updates are only available on Android.');
    }
    final apkUrl = release.apkUrl;
    if (apkUrl == null) {
      throw StateError('Release does not include an APK.');
    }
    final directory = await getApplicationSupportDirectory();
    final updateDirectory = Directory('${directory.path}${Platform.pathSeparator}updates');
    await updateDirectory.create(recursive: true);
    final apk = File('${updateDirectory.path}${Platform.pathSeparator}rangebuddy-update.apk');
    final response = await http.Client().send(http.Request('GET', Uri.parse(apkUrl)));
    if (response.statusCode != 200) {
      throw StateError('APK download failed (${response.statusCode})');
    }
    final sink = apk.openWrite();
    await response.stream.pipe(sink);
    final checksumUrl = release.checksumUrl;
    if (checksumUrl == null) {
      await apk.delete();
      throw StateError('Release does not include an APK checksum.');
    }
    final checksumResponse = await http.get(Uri.parse(checksumUrl));
    if (checksumResponse.statusCode != 200) {
      await apk.delete();
      throw StateError('APK checksum download failed (${checksumResponse.statusCode})');
    }
    final expected = checksumResponse.body.trim().split(RegExp(r'\s+')).first;
    final actual = (await sha256.bind(apk.openRead()).first).toString();
    if (expected.toLowerCase() != actual.toLowerCase()) {
      await apk.delete();
      throw StateError('APK integrity check failed.');
    }
    await _channel.invokeMethod<void>('installApk', {'path': apk.path});
  }
}

class GitHubRelease {
  final String version;
  final String notes;
  final String pageUrl;
  final String? apkUrl;
  final String? checksumUrl;
  const GitHubRelease({
    required this.version,
    required this.notes,
    required this.pageUrl,
    required this.apkUrl,
    required this.checksumUrl,
  });

  bool get isNewerThanInstalled => _compareVersions(version, GitHubReleaseService.installedVersion) > 0;
}

int _compareVersions(String left, String right) {
  final a = left.split('.').map((part) => int.tryParse(part) ?? 0).toList();
  final b = right.split('.').map((part) => int.tryParse(part) ?? 0).toList();
  for (var i = 0; i < 3; i++) {
    final difference = (i < a.length ? a[i] : 0) - (i < b.length ? b[i] : 0);
    if (difference != 0) return difference;
  }
  return 0;
}

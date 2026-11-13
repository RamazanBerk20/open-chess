import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Project + funding links (single source of truth).
const String kRepoOwner = 'RamazanBerk20';
const String kRepoName = 'open-chess';
const String repoUrl = 'https://github.com/$kRepoOwner/$kRepoName';
const String sponsorUrl = 'https://github.com/sponsors/$kRepoOwner';
const String _latestReleaseApi =
    'https://api.github.com/repos/$kRepoOwner/$kRepoName/releases/latest';

/// A newer release found on GitHub.
class UpdateInfo {
  final String version; // e.g. "1.0.1"
  final String htmlUrl; // release page
  final String? assetUrl; // this OS's installer asset, if present
  const UpdateInfo({
    required this.version,
    required this.htmlUrl,
    this.assetUrl,
  });

  /// Where Download goes: this platform's artifact, else the release page.
  String get downloadUrl => assetUrl ?? htmlUrl;
}

/// The release asset for [os] (`Platform.operatingSystem`): the APK on
/// Android, the installer on Windows, the AppImage on Linux. Null otherwise,
/// so desktop never downloads an APK.
String? pickUpdateAsset(List<(String, String)> assets, String os) {
  final suffix = switch (os) {
    'android' => '.apk',
    'windows' => '.exe',
    'linux' => '.appimage',
    _ => null,
  };
  if (suffix == null) return null;
  for (final (name, url) in assets) {
    if (name.toLowerCase().endsWith(suffix)) return url;
  }
  return null;
}

/// Open [url] in the external browser. Returns false if it couldn't open.
/// (No `canLaunchUrl` pre-check: on Android 11+ it needs package visibility
/// and wrongly reports false; `launchUrl` itself reports failure.)
Future<bool> openUrl(String url) async {
  try {
    return await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}

/// The running app's version string (e.g. "1.0.0").
Future<String> currentVersion() async =>
    (await PackageInfo.fromPlatform()).version;

/// Query GitHub Releases for a version newer than the running build. Returns
/// null when up to date or the check fails (offline, rate-limited, no release).
Future<UpdateInfo?> checkForUpdate() async {
  try {
    final current = _parse((await PackageInfo.fromPlatform()).version);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    final req = await client.getUrl(Uri.parse(_latestReleaseApi));
    req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    req.headers.set(HttpHeaders.userAgentHeader, 'open-chess-app');
    final resp = await req.close();
    if (resp.statusCode != 200) {
      client.close();
      return null;
    }
    final body = await resp.transform(utf8.decoder).join();
    client.close();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final tag = (json['tag_name'] as String?) ?? '';
    if (!_isNewer(_parse(tag), current)) return null;
    final assets = [
      for (final a in (json['assets'] as List?) ?? const [])
        if (a is Map && a['browser_download_url'] is String)
          ((a['name'] as String?) ?? '', a['browser_download_url'] as String),
    ];
    return UpdateInfo(
      version: tag.replaceFirst(RegExp(r'^v'), ''),
      htmlUrl: (json['html_url'] as String?) ?? repoUrl,
      assetUrl: pickUpdateAsset(assets, Platform.operatingSystem),
    );
  } catch (_) {
    return null; // offline / parse error / rate-limited — fail quietly
  }
}

List<int> _parse(String v) => v
    .replaceFirst(RegExp(r'^v'), '')
    .split('+')
    .first
    .split('.')
    .map((p) => int.tryParse(p.trim()) ?? 0)
    .toList();

bool _isNewer(List<int> a, List<int> b) {
  for (var i = 0; i < a.length || i < b.length; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}

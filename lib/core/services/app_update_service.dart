import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Data returned by [appUpdateProvider].
///
/// Firestore document — `app_config/latest_version`:
/// ```json
/// {
///   "version":        "1.0.3",
///   "build_number":   71,
///   "force_update":   false,
///   "update_message": "Novidades e correções de bugs.",
///   "android_url":    "https://play.google.com/store/apps/details?id=com.alexdev.myfinanceapp",
///   "ios_url":        "https://apps.apple.com/app/id..."
/// }
/// ```
class AppUpdateInfo {
  final bool hasUpdate;
  final bool forceUpdate;
  final String storeUrl;
  final String message;

  const AppUpdateInfo({
    required this.hasUpdate,
    required this.storeUrl,
    this.forceUpdate = false,
    this.message = '',
  });

  static const none = AppUpdateInfo(hasUpdate: false, storeUrl: '');
}

final appUpdateProvider = FutureProvider<AppUpdateInfo>((ref) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('app_config')
        .doc('latest_version')
        .get();

    if (!doc.exists) return AppUpdateInfo.none;

    final data = doc.data()!;
    final latestVersion = (data['version'] as String?)?.trim() ?? '';
    final latestBuild = (data['build_number'] as num?)?.toInt() ?? 0;
    final forceUpdate = data['force_update'] as bool? ?? false;
    final message = data['update_message'] as String? ?? '';
    final androidUrl = data['android_url'] as String? ?? '';
    final iosUrl = data['ios_url'] as String? ?? '';

    if (latestVersion.isEmpty && latestBuild == 0) return AppUpdateInfo.none;

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version.trim();
    final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

    final hasUpdate = _isNewer(latestVersion, latestBuild, currentVersion, currentBuild);
    final storeUrl =
        defaultTargetPlatform == TargetPlatform.iOS ? iosUrl : androidUrl;

    return AppUpdateInfo(
      hasUpdate: hasUpdate,
      forceUpdate: forceUpdate && hasUpdate,
      storeUrl: storeUrl,
      message: message,
    );
  } catch (_) {
    return AppUpdateInfo.none;
  }
});

/// Returns true when the latest version/build is strictly newer than current.
/// Compares version segments first; if equal, compares build numbers.
bool _isNewer(
  String latestVersion,
  int latestBuild,
  String currentVersion,
  int currentBuild,
) {
  List<int> parse(String v) =>
      v.split('.').take(3).map((s) => int.tryParse(s) ?? 0).toList();

  final l = parse(latestVersion);
  final c = parse(currentVersion);

  for (var i = 0; i < 3; i++) {
    final lv = i < l.length ? l[i] : 0;
    final cv = i < c.length ? c[i] : 0;
    if (lv > cv) return true;
    if (lv < cv) return false;
  }

  // Versions are equal — compare build numbers
  return latestBuild > currentBuild;
}

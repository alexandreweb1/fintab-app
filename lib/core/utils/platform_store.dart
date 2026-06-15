// Platform-aware app-store naming.
//
// App Store Review Guideline 2.3.10 forbids the iOS binary from referencing
// competing platforms (e.g. "Google Play"). These helpers let shared UI and
// legal copy show only the store relevant to the running platform: Apple on
// iOS/macOS, Google on Android, and both on the web build (which Apple does
// not review).

import 'package:flutter/foundation.dart';

/// True on Apple platforms (iOS/macOS); false on Android and web.
bool get isApplePlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

/// True on native Android; false on Apple and web.
bool get isAndroidPlatform =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Short store label for the running platform.
String get storeName {
  if (kIsWeb) return 'App Store / Google Play';
  if (isAndroidPlatform) return 'Google Play';
  return 'App Store';
}

/// Full store name ("Apple App Store" / "Google Play Store") for the platform.
String get storeNameFull {
  if (kIsWeb) return 'Apple App Store / Google Play Store';
  if (isAndroidPlatform) return 'Google Play Store';
  return 'Apple App Store';
}

/// Public store URL for the running platform, used in share/referral messages.
///
/// Platform-aware on purpose: the iOS build must not reference Google Play
/// (App Store Review Guideline 2.3.10), so a share started on iOS links only to
/// the App Store, and one started on Android links only to Google Play.
String get storeUrl {
  if (isAndroidPlatform) {
    return 'https://play.google.com/store/apps/details?id=com.alexdev.myfinanceapp';
  }
  return 'https://apps.apple.com/app/id6776314028';
}

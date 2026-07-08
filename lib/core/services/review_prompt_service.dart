import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_service.dart';

/// Store-review nudge ("avalie o app"), shown when the app opens until the
/// user rates it (or says they already have).
///
/// Neither store reveals whether a user actually left a review, so "already
/// rated" is tracked locally: once the user goes to the store through this
/// flow (or taps "já avaliei") we stop asking on this device.
class ReviewPromptService {
  ReviewPromptService._();
  static final ReviewPromptService instance = ReviewPromptService._();

  static const _kOpenCountKey = 'app_open_count';
  static const _kDoneKey = 'review_done';

  /// iOS App Store numeric id (Android resolves by package name).
  static const _appStoreId = '6776314028';

  /// Counts this app open and tells whether the nudge should be shown now:
  /// native platforms only (web has no store), every open except the very
  /// first (that session belongs to onboarding), until the user rates.
  Future<bool> registerOpenAndShouldPrompt() async {
    if (kIsWeb) return false;
    final prefs = await SharedPreferences.getInstance();
    final opens = (prefs.getInt(_kOpenCountKey) ?? 0) + 1;
    await prefs.setInt(_kOpenCountKey, opens);
    if (prefs.getBool(_kDoneKey) ?? false) return false;
    return opens >= 2;
  }

  /// Opens the store review page and stops future nudges.
  ///
  /// Deliberately NOT requestReview() (SKStoreReviewController / Play in-app
  /// review): those are quota-limited and silently show nothing when
  /// throttled or on sideloaded builds — a dead "Avaliar" button.
  /// openStoreListing always lands on the store page.
  Future<void> rate() async {
    AnalyticsService.instance.logEvent('review_prompt_accepted');
    await _markDone();
    await InAppReview.instance.openStoreListing(appStoreId: _appStoreId);
  }

  /// The user says they already rated — stop asking.
  Future<void> markAlreadyRated() async {
    AnalyticsService.instance.logEvent('review_prompt_already_rated');
    await _markDone();
  }

  /// "Not now" — will ask again on the next open.
  void logDismissed() {
    AnalyticsService.instance.logEvent('review_prompt_dismissed');
  }

  Future<void> _markDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDoneKey, true);
  }
}

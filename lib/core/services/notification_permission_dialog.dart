import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'notification_listener_service.dart';

/// Shows an explanation dialog and redirects to Android's Notification Access
/// settings when the user hasn't granted the permission yet.
///
/// Reading notifications to detect transactions is an Android-only feature, so
/// the dialog is never shown on iOS/macOS/web — otherwise it would prompt on
/// every launch (permission can never be granted on those platforms).
Future<void> showNotificationPermissionDialogIfNeeded(
    BuildContext context) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  final granted = await NotificationListenerBridge.isPermissionGranted();
  if (granted) return;
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (ctx) => const _NotificationPermissionDialog(),
  );
}

class _NotificationPermissionDialog extends StatelessWidget {
  const _NotificationPermissionDialog();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      icon: Icon(Icons.notifications_active_outlined,
          size: 40, color: cs.primary),
      title: Text(AppLocalizations.of(context).detectTransactionsDialogTitle),
      content: Text(AppLocalizations.of(context).detectTransactionsDialogContent),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).notNow),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.settings_outlined, size: 18),
          label: Text(AppLocalizations.of(context).enable),
          onPressed: () async {
            Navigator.of(context).pop();
            await NotificationListenerBridge.openPermissionSettings();
          },
        ),
      ],
    );
  }
}

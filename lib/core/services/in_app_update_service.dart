import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// Handles Google Play In-App Update (Android only).
///
/// - Flexible update: baixa em segundo plano, usuário continua usando o app.
///   Ao completar o download, um banner/snackbar pede para reiniciar.
/// - Immediate update: tela bloqueante obrigatória (usado quando force_update=true).
class InAppUpdateService {
  InAppUpdateService._();
  static final instance = InAppUpdateService._();

  /// Checks for an available update on the Play Store.
  /// [forceImmediate] = true triggers the blocking immediate flow.
  /// Returns false if not on Android, IAP not available, or no update found.
  Future<bool> checkAndPrompt({bool forceImmediate = false}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;

    try {
      final info = await InAppUpdate.checkForUpdate();

      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return false;
      }

      if (forceImmediate) {
        await InAppUpdate.performImmediateUpdate();
      } else {
        final result = await InAppUpdate.startFlexibleUpdate();
        if (result == AppUpdateResult.success) {
          await InAppUpdate.completeFlexibleUpdate();
        }
      }
      return true;
    } catch (_) {
      // Silently ignore: Play Store not available (debug builds, emulator, etc.)
      return false;
    }
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_lock_service.dart';

/// Reactive state of the app lock.
class AppLockState {
  final bool enabled;
  final bool biometricEnabled;
  final bool biometricAvailable;
  final bool locked;

  const AppLockState({
    required this.enabled,
    required this.biometricEnabled,
    required this.biometricAvailable,
    required this.locked,
  });

  const AppLockState.initial()
      : enabled = false,
        biometricEnabled = false,
        biometricAvailable = false,
        locked = false;

  AppLockState copyWith({
    bool? enabled,
    bool? biometricEnabled,
    bool? biometricAvailable,
    bool? locked,
  }) =>
      AppLockState(
        enabled: enabled ?? this.enabled,
        biometricEnabled: biometricEnabled ?? this.biometricEnabled,
        biometricAvailable: biometricAvailable ?? this.biometricAvailable,
        locked: locked ?? this.locked,
      );
}

class AppLockNotifier extends StateNotifier<AppLockState> {
  final AppLockService _service;

  AppLockNotifier(this._service) : super(const AppLockState.initial()) {
    _refresh();
  }

  Future<void> _refresh() async {
    final enabled = await _service.isEnabled();
    final hasPin = await _service.hasPin();
    final biometric = await _service.isBiometricEnabled();
    final bioAvailable = await _service.canUseBiometrics();
    state = state.copyWith(
      enabled: enabled && hasPin,
      biometricEnabled: biometric,
      biometricAvailable: bioAvailable,
      locked: enabled && hasPin,
    );
  }

  /// Called when the app goes to background long enough that we should re-lock.
  void lock() {
    if (state.enabled) {
      state = state.copyWith(locked: true);
    }
  }

  /// Called after successful PIN or biometric verification.
  void unlock() {
    state = state.copyWith(locked: false);
  }

  Future<bool> verifyPin(String pin) => _service.verifyPin(pin);

  Future<bool> authenticateWithBiometrics(String reason) =>
      _service.authenticateWithBiometrics(reason);

  Future<void> setPin(String pin) async {
    await _service.setPin(pin);
    state = state.copyWith(enabled: true, locked: false);
  }

  Future<void> disable() async {
    await _service.disable();
    state = state.copyWith(
      enabled: false,
      biometricEnabled: false,
      locked: false,
    );
  }

  Future<void> setBiometricEnabled(bool value) async {
    await _service.setBiometricEnabled(value);
    state = state.copyWith(biometricEnabled: value);
  }
}

final appLockServiceProvider = Provider<AppLockService>((ref) {
  return AppLockService();
});

final appLockProvider =
    StateNotifierProvider<AppLockNotifier, AppLockState>((ref) {
  return AppLockNotifier(ref.read(appLockServiceProvider));
});

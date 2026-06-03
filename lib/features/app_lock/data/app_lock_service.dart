import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles PIN storage (hashed + salted) and biometric authentication.
///
/// Storage layout:
///   - SecureStorage `pin_hash` / `pin_salt`        — PIN credentials
///   - SharedPreferences `app_lock_enabled`          — user toggled ON
///   - SharedPreferences `app_lock_biometric`        — biometric enabled
class AppLockService {
  static const _kPinHash = 'app_lock_pin_hash';
  static const _kPinSalt = 'app_lock_pin_salt';
  static const _kEnabled = 'app_lock_enabled';
  static const _kBiometric = 'app_lock_biometric';

  final FlutterSecureStorage _secure;
  final LocalAuthentication _localAuth;

  AppLockService({
    FlutterSecureStorage? secure,
    LocalAuthentication? localAuth,
  })  : _secure = secure ?? const FlutterSecureStorage(),
        _localAuth = localAuth ?? LocalAuthentication();

  // ── Availability ──────────────────────────────────────────────────────────

  bool get isPlatformSupported => !kIsWeb;

  Future<bool> canUseBiometrics() async {
    if (!isPlatformSupported) return false;
    try {
      final supported = await _localAuth.isDeviceSupported();
      if (!supported) return false;
      final canCheck = await _localAuth.canCheckBiometrics;
      return canCheck;
    } catch (_) {
      return false;
    }
  }

  // ── Flags ─────────────────────────────────────────────────────────────────

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabled) ?? false;
  }

  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kBiometric) ?? false;
  }

  Future<void> setBiometricEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBiometric, value);
  }

  // ── PIN ───────────────────────────────────────────────────────────────────

  Future<bool> hasPin() async {
    final h = await _secure.read(key: _kPinHash);
    return h != null && h.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
    await _secure.write(key: _kPinSalt, value: salt);
    await _secure.write(key: _kPinHash, value: hash);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, true);
  }

  Future<bool> verifyPin(String pin) async {
    final storedHash = await _secure.read(key: _kPinHash);
    final salt = await _secure.read(key: _kPinSalt);
    if (storedHash == null || salt == null) return false;
    return _hashPin(pin, salt) == storedHash;
  }

  Future<void> disable() async {
    await _secure.delete(key: _kPinHash);
    await _secure.delete(key: _kPinSalt);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, false);
    await prefs.setBool(_kBiometric, false);
  }

  // ── Biometric prompt ──────────────────────────────────────────────────────

  Future<bool> authenticateWithBiometrics(String reason) async {
    if (!isPlatformSupported) return false;
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  String _hashPin(String pin, String saltB64) {
    final salt = base64Decode(saltB64);
    final bytes = Uint8List.fromList([...salt, ...utf8.encode(pin)]);
    return sha256.convert(bytes).toString();
  }

  String _generateSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64Encode(bytes);
  }
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Known Brazilian bank apps ────────────────────────────────────────────────

/// Map of Android package name → user-friendly display name.
const Map<String, String> knownBankApps = {
  'com.nu.production': 'Nubank',
  'br.com.bb.android': 'Banco do Brasil',
  'com.itau': 'Itaú',
  'com.bradesco': 'Bradesco',
  'br.com.gabba.Caixa': 'Caixa Econômica',
  'com.santander.app': 'Santander',
  'br.com.intermedium': 'Inter',
  'com.c6bank.app': 'C6 Bank',
  'com.picpay': 'PicPay',
  'com.mercadopago.wallet': 'Mercado Pago',
  'br.com.uol.ps.myaccount': 'PagBank',
  'br.com.bradesco.next': 'Next',
  'com.neon': 'Neon',
  'br.com.original.bank': 'Original',
  'br.com.sicoob.app': 'Sicoob',
  'br.com.sicredi.app': 'Sicredi',
  'com.btgpactual.pangea': 'BTG Pactual',
  'com.will.app': 'Will Bank',
  'com.pagseguro.ecommerce': 'PagSeguro',
  'br.com.xpi.investor': 'XP Investimentos',
  'com.stone.mobile.banking': 'Stone',
  'com.iti.itau': 'Iti (Itaú)',
  'br.gov.caixa.tem': 'Caixa Tem',
  'br.com.safra.SafraNet': 'Safra',
};

/// Returns the display name for a package, using the known list or
/// extracting the last segment from the package name.
String bankDisplayName(String packageName) {
  final known = knownBankApps[packageName];
  if (known != null) return known;
  final parts = packageName.split('.');
  final last = parts.isNotEmpty ? parts.last : packageName;
  if (last.isEmpty) return packageName;
  return last[0].toUpperCase() + last.substring(1);
}

// ── Allowed packages provider (opt-in model) ────────────────────────────────

const _kPrefKey = 'allowed_monitor_packages';
const _kInitializedKey = 'allowed_monitor_initialized';

const _nativeChannel =
    MethodChannel('com.alexdev.myfinanceapp/notification_permission');

/// Set of package names the user has ALLOWED (opted-in to monitor).
/// On first run, all known bank apps are pre-enabled.
final allowedAppPackagesProvider =
    StateNotifierProvider<_AllowedAppsNotifier, Set<String>>(
  (ref) => _AllowedAppsNotifier(),
);

class _AllowedAppsNotifier extends StateNotifier<Set<String>> {
  _AllowedAppsNotifier() : super({}) {
    _loaded = _load();
  }

  late final Future<void> _loaded;
  Future<void> get loaded => _loaded;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final initialized = prefs.getBool(_kInitializedKey) ?? false;

    if (!initialized) {
      // First run: migrate from old blocked list or enable all known banks
      final oldBlocked = prefs.getString('blocked_bank_packages');
      if (oldBlocked != null) {
        // Migration: allowed = known banks minus previously blocked
        try {
          final blockedList = (jsonDecode(oldBlocked) as List).cast<String>();
          final blockedSet = blockedList.toSet();
          state = knownBankApps.keys
              .where((pkg) => !blockedSet.contains(pkg))
              .toSet();
        } catch (_) {
          state = knownBankApps.keys.toSet();
        }
        await prefs.remove('blocked_bank_packages');
      } else {
        state = knownBankApps.keys.toSet();
      }
      await prefs.setBool(_kInitializedKey, true);
      await _persist();
    } else {
      final json = prefs.getString(_kPrefKey);
      if (json != null) {
        try {
          final list = (jsonDecode(json) as List).cast<String>();
          state = list.toSet();
        } catch (_) {}
      }
    }
    _syncToNative();
  }

  Future<void> toggle(String packageName) async {
    final updated = Set<String>.from(state);
    if (updated.contains(packageName)) {
      updated.remove(packageName);
    } else {
      updated.add(packageName);
    }
    state = updated;
    await _persist();
  }

  bool isAllowed(String packageName) => state.contains(packageName);

  Future<void> enableAll(Set<String> packages) async {
    state = Set<String>.from(packages);
    await _persist();
  }

  Future<void> disableAll() async {
    state = {};
    await _persist();
  }

  Future<void> addCustomApp(String packageName) async {
    final updated = Set<String>.from(state);
    updated.add(packageName);
    state = updated;
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefKey, jsonEncode(state.toList()));
    await _syncToNative();
  }

  /// Sends the allowed list to the native service via MethodChannel so
  /// notifications are only processed for allowed apps.
  Future<void> _syncToNative() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _nativeChannel.invokeMethod(
          'updateAllowedPackages', state.toList());
    } catch (e) {
      debugPrint('[AppFilter] Failed to sync to native: $e');
    }
  }
}

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/blockable_app.dart';
import 'native_blocker.dart';

/// Single source of truth for the app's configuration.
///
/// Flutter owns the config (PIN, which packages are blocked, whether blocking
/// is on) and persists it with [SharedPreferences]. Every change is also pushed
/// to the native accessibility service via [NativeBlocker] so the two stay in
/// sync.
class BlockerStore extends ChangeNotifier {
  static const _kPinHash = 'pin_hash';
  static const _kBlocked = 'blocked_packages';
  static const _kEnabled = 'blocking_enabled';
  // Static salt: this only guards against casual reading of the stored hash on
  // a rooted device; it is not meant to withstand offline brute force.
  static const _salt = 'kidsafe::v1::';

  late SharedPreferences _prefs;

  bool _blockingEnabled = true;
  Set<String> _blockedPackages = {kDefaultBlockedPackage};
  String? _pinHash;

  bool get blockingEnabled => _blockingEnabled;
  Set<String> get blockedPackages => Set.unmodifiable(_blockedPackages);
  bool get hasPin => _pinHash != null;
  int get blockedCount => _blockedPackages.length;

  bool isBlocked(String packageName) => _blockedPackages.contains(packageName);

  /// Loads persisted state and mirrors it to the native side.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _pinHash = _prefs.getString(_kPinHash);
    _blockingEnabled = _prefs.getBool(_kEnabled) ?? true;
    final stored = _prefs.getStringList(_kBlocked);
    _blockedPackages =
        (stored == null) ? {kDefaultBlockedPackage} : stored.toSet();
    await _syncNative();
    notifyListeners();
  }

  String _hash(String pin) =>
      sha256.convert(utf8.encode('$_salt$pin')).toString();

  /// Sets the parent PIN for the first time (or resets it).
  Future<void> setPin(String pin) async {
    _pinHash = _hash(pin);
    await _prefs.setString(_kPinHash, _pinHash!);
    notifyListeners();
  }

  /// Returns true if [pin] matches the stored PIN.
  bool verifyPin(String pin) => _pinHash != null && _hash(pin) == _pinHash;

  /// Master on/off switch for blocking.
  Future<void> setBlockingEnabled(bool value) async {
    _blockingEnabled = value;
    await _prefs.setBool(_kEnabled, value);
    await NativeBlocker.setBlockingEnabled(value);
    notifyListeners();
  }

  /// Adds or removes a package from the blocked set.
  Future<void> setAppBlocked(String packageName, bool blocked) async {
    if (blocked) {
      _blockedPackages.add(packageName);
    } else {
      _blockedPackages.remove(packageName);
    }
    await _prefs.setStringList(_kBlocked, _blockedPackages.toList());
    await NativeBlocker.setBlockedPackages(_blockedPackages);
    notifyListeners();
  }

  Future<void> _syncNative() async {
    await NativeBlocker.setBlockedPackages(_blockedPackages);
    await NativeBlocker.setBlockingEnabled(_blockingEnabled);
  }
}

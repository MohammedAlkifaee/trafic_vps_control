import 'package:flutter/services.dart';

/// Thin wrapper over the platform method channel that talks to the native
/// Android accessibility service and permission screens.
///
/// All methods are safe to call on any platform; on non-Android platforms the
/// permission checks simply report `false` and the setters are no-ops, so the
/// Flutter UI keeps working (e.g. when running on desktop for development).
class NativeBlocker {
  NativeBlocker._();

  static const MethodChannel _channel = MethodChannel('com.kidsafe/blocker');

  /// Whether our accessibility service is currently enabled in system settings.
  static Future<bool> isAccessibilityEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isAccessibilityEnabled') ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Opens the system Accessibility settings so the parent can enable the
  /// service (it cannot be enabled programmatically, by design).
  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } on MissingPluginException {
      // Not on Android; ignore.
    }
  }

  /// Whether the "draw over other apps" permission has been granted.
  static Future<bool> canDrawOverlays() async {
    try {
      return await _channel.invokeMethod<bool>('canDrawOverlays') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Opens the system overlay-permission screen for this app.
  static Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } on MissingPluginException {
      // Not on Android; ignore.
    }
  }

  /// Pushes the current set of blocked package names to the native service.
  static Future<void> setBlockedPackages(Set<String> packages) async {
    try {
      await _channel.invokeMethod('setBlockedPackages', {
        'packages': packages.toList(),
      });
    } on MissingPluginException {
      // Not on Android; ignore.
    }
  }

  /// Turns blocking on or off natively.
  static Future<void> setBlockingEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setBlockingEnabled', {'enabled': enabled});
    } on MissingPluginException {
      // Not on Android; ignore.
    }
  }
}

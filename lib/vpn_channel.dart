import 'package:flutter/services.dart';

/// Bridge to the native WireGuard controller in MainActivity.kt.
class VpnChannel {
  VpnChannel._();

  static const MethodChannel _channel = MethodChannel('com.kidsafe/vpn');

  /// Brings the tunnel up. Triggers the one-time system VPN-consent dialog on
  /// first use; the returned future completes only after consent + connect.
  /// Throws [PlatformException] if consent is denied or the tunnel fails.
  static Future<String> connect() async =>
      (await _channel.invokeMethod<String>('connect')) ?? 'DOWN';

  /// Tears the tunnel down.
  static Future<String> disconnect() async =>
      (await _channel.invokeMethod<String>('disconnect')) ?? 'DOWN';

  /// Current backend state: 'UP' or 'DOWN'.
  static Future<String> status() async =>
      (await _channel.invokeMethod<String>('status')) ?? 'DOWN';
}

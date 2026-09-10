import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'vpn_channel.dart';

enum VpnStatus { connecting, connected, error }

/// Launch screen: connects the tunnel and then closes the app. There is no
/// disconnect control — the child cannot turn protection off from here. A
/// parent manages it from Android's VPN settings.
class VpnHome extends StatefulWidget {
  const VpnHome({super.key});

  @override
  State<VpnHome> createState() => _VpnHomeState();
}

class _VpnHomeState extends State<VpnHome> {
  VpnStatus _status = VpnStatus.connecting;
  String? _error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final state = await _safeStatus();
    if (state == 'UP') {
      _set(VpnStatus.connected);
      _exitSoon();
    } else {
      _connect();
    }
  }

  Future<String> _safeStatus() async {
    try {
      return await VpnChannel.status();
    } on PlatformException {
      return 'DOWN';
    } on MissingPluginException {
      return 'DOWN';
    }
  }

  Future<void> _connect() async {
    _set(VpnStatus.connecting);
    try {
      final r = await VpnChannel.connect();
      if (r == 'UP') {
        _set(VpnStatus.connected);
        _exitSoon();
      } else {
        _set(VpnStatus.error, 'Could not connect. Tap to retry.');
      }
    } on PlatformException catch (e) {
      _set(VpnStatus.error, e.message ?? 'Could not connect. Tap to retry.');
    } on MissingPluginException {
      _set(VpnStatus.error, 'VPN is not available on this device.');
    }
  }

  /// Close the app shortly after connecting. The VPN keeps running because it
  /// is a foreground service, independent of this activity.
  Future<void> _exitSoon() async {
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    await SystemNavigator.pop();
  }

  void _set(VpnStatus s, [String? err]) {
    if (!mounted) return;
    setState(() {
      _status = s;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StatusBadge(status: _status),
                const SizedBox(height: 28),
                Text(
                  _title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  _subtitle,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                ),
                if (_status == VpnStatus.error) ...[
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _connect,
                    child: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _title => switch (_status) {
        VpnStatus.connected => 'Protected',
        VpnStatus.connecting => 'Connecting…',
        VpnStatus.error => 'Connection problem',
      };

  String get _subtitle => switch (_status) {
        VpnStatus.connected => 'Protection is on. You can close this.',
        VpnStatus.connecting => 'Turning on protection…',
        VpnStatus.error => _error ?? 'Something went wrong.',
      };
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final VpnStatus status;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (status) {
      VpnStatus.connected => const Color(0xFF22C55E),
      VpnStatus.connecting => const Color(0xFF3B82F6),
      VpnStatus.error => const Color(0xFFEF4444),
    };
    final IconData icon = switch (status) {
      VpnStatus.connected => Icons.verified_user,
      VpnStatus.connecting => Icons.shield_outlined,
      VpnStatus.error => Icons.error_outline,
    };
    return Container(
      width: 132,
      height: 132,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color, width: 3),
      ),
      child: Icon(icon, size: 62, color: color),
    );
  }
}

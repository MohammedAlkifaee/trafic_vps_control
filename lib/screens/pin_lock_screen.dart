import 'package:flutter/material.dart';

import '../services/blocker_store.dart';
import '../widgets/pin_pad.dart';
import 'home_screen.dart';

/// Gate shown on every launch. The child can open the app, but without the
/// parent PIN they cannot reach the settings that would let them unblock apps.
class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key, required this.store});
  final BlockerStore store;

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  final _padKey = GlobalKey<PinPadState>();
  String? _error;

  void _onCompleted(String pin) {
    if (widget.store.verifyPin(pin)) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(store: widget.store)),
      );
    } else {
      setState(() => _error = 'Wrong PIN. Try again.');
      _padKey.currentState?.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              const SizedBox(height: 12),
              const Icon(Icons.lock, size: 56, color: Color(0xFF3B82F6)),
              Expanded(
                child: PinPad(
                  key: _padKey,
                  title: 'Enter parent PIN',
                  subtitle: 'This unlocks the blocking settings.',
                  errorText: _error,
                  onCompleted: _onCompleted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

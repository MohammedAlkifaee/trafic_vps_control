import 'package:flutter/material.dart';

import '../services/blocker_store.dart';
import '../widgets/pin_pad.dart';
import 'home_screen.dart';

/// Shown on first launch so the parent can create a 4-digit PIN. The PIN is
/// what protects every setting from the child, so it must be entered twice.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key, required this.store});
  final BlockerStore store;

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final _padKey = GlobalKey<PinPadState>();
  String? _first;
  String? _error;

  void _onCompleted(String pin) async {
    if (_first == null) {
      setState(() {
        _first = pin;
        _error = null;
      });
      _padKey.currentState?.reset();
    } else if (_first == pin) {
      await widget.store.setPin(pin);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(store: widget.store)),
      );
    } else {
      setState(() {
        _first = null;
        _error = 'PINs did not match. Start again.';
      });
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
              const Icon(Icons.shield_moon, size: 56, color: Color(0xFF3B82F6)),
              const SizedBox(height: 8),
              Text('Set a parent PIN',
                  style: Theme.of(context).textTheme.titleMedium),
              Expanded(
                child: PinPad(
                  key: _padKey,
                  title: _first == null ? 'Create PIN' : 'Confirm PIN',
                  subtitle: _first == null
                      ? 'Only you should know this. The child cannot change any setting without it.'
                      : 'Enter the same PIN again to confirm.',
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

import 'package:flutter/material.dart';

/// A numeric keypad that collects a fixed-length PIN and fires [onCompleted]
/// once [length] digits have been entered. The parent widget decides what to
/// do next (verify, confirm, etc.) and can [reset] the pad.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.title,
    this.subtitle,
    this.length = 4,
    required this.onCompleted,
    this.errorText,
  });

  final String title;
  final String? subtitle;
  final int length;
  final ValueChanged<String> onCompleted;
  final String? errorText;

  @override
  State<PinPad> createState() => PinPadState();
}

class PinPadState extends State<PinPad> {
  String _entered = '';

  /// Clears the current entry (call after a failed/handled attempt).
  void reset() => setState(() => _entered = '');

  void _onDigit(String d) {
    if (_entered.length >= widget.length) return;
    setState(() => _entered += d);
    if (_entered.length == widget.length) {
      // Defer so the last dot paints before the parent reacts.
      final value = _entered;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onCompleted(value);
      });
    }
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(widget.title,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              widget.subtitle!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
        const SizedBox(height: 28),
        _Dots(length: widget.length, filled: _entered.length),
        SizedBox(
          height: 24,
          child: widget.errorText != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(widget.errorText!,
                      style: TextStyle(color: theme.colorScheme.error)),
                )
              : null,
        ),
        const SizedBox(height: 12),
        _Keypad(onDigit: _onDigit, onBackspace: _onBackspace),
      ],
    );

    // Center when there is room; scroll instead of overflowing on short
    // screens (small devices, landscape, split-screen).
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(child: content),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.length, required this.filled});
  final int length;
  final int filled;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final on = i < filled;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? color : Colors.transparent,
            border: Border.all(color: color, width: 2),
          ),
        );
      }),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onDigit, required this.onBackspace});
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    Widget key(String label, {VoidCallback? onTap, Widget? child}) {
      return SizedBox(
        width: 78,
        height: 78,
        child: InkWell(
          onTap: onTap ?? () => onDigit(label),
          customBorder: const CircleBorder(),
          child: Center(
            child: child ??
                Text(label,
                    style: const TextStyle(
                        fontSize: 30, fontWeight: FontWeight.w500)),
          ),
        ),
      );
    }

    Widget row(List<Widget> children) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: children,
        );

    return Column(
      children: [
        row([key('1'), key('2'), key('3')]),
        row([key('4'), key('5'), key('6')]),
        row([key('7'), key('8'), key('9')]),
        row([
          const SizedBox(width: 78, height: 78),
          key('0'),
          key('',
              onTap: onBackspace,
              child: const Icon(Icons.backspace_outlined, size: 26)),
        ]),
      ],
    );
  }
}

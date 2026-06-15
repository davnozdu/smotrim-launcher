/*
 * Smotrim.CZ Launcher
 * Based on FLauncher (C) 2021 Étienne Fesser — GPLv3.
 */

import 'package:flutter/material.dart';

/// Remote-friendly on-screen numeric keypad for entering an 8-digit code.
/// Calls [onCompleted] when the OK key is pressed with a full-length code.
class PinPad extends StatefulWidget {
  final int length;
  final ValueChanged<String> onCompleted;
  final String? errorText;

  const PinPad({super.key, this.length = 8, required this.onCompleted, this.errorText});

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _code = "";

  void _tap(String d) {
    if (_code.length >= widget.length) return;
    setState(() => _code += d);
  }

  void _del() {
    if (_code.isEmpty) return;
    setState(() => _code = _code.substring(0, _code.length - 1));
  }

  void _ok() {
    if (_code.length == widget.length) widget.onCompleted(_code);
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.length, (i) {
            final filled = i < _code.length;
            return Container(
              width: 14,
              height: 14,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? accent : Colors.white24,
              ),
            );
          }),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 10),
          Text(widget.errorText!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
        ],
        const SizedBox(height: 16),
        FocusTraversalGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final row in const [
                ["1", "2", "3"],
                ["4", "5", "6"],
                ["7", "8", "9"],
              ])
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [for (final d in row) _key(d, () => _tap(d), autofocus: d == "1")],
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _key("⌫", _del),
                  _key("0", () => _tap("0")),
                  _key("OK", _ok, highlight: true),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _key(String label, VoidCallback onTap, {bool autofocus = false, bool highlight = false}) {
    return _PadKey(label: label, onTap: onTap, autofocus: autofocus, highlight: highlight);
  }
}

class _PadKey extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool autofocus;
  final bool highlight;

  const _PadKey({required this.label, required this.onTap, this.autofocus = false, this.highlight = false});

  @override
  State<_PadKey> createState() => _PadKeyState();
}

class _PadKeyState extends State<_PadKey> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final base = widget.highlight ? accent.withOpacity(0.85) : Colors.white10;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onTap()),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(onInvoke: (_) => widget.onTap()),
        },
        child: Focus(
          autofocus: widget.autofocus,
          onFocusChange: (f) => setState(() => _focused = f),
          child: Material(
            color: _focused ? accent : base,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 64,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: _focused ? Border.all(color: Colors.white, width: 2) : null,
                ),
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: widget.label.length > 1 ? 18 : 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

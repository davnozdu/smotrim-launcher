/*
 * Smotrim.CZ Launcher
 * Based on FLauncher (C) 2021 Étienne Fesser — GPLv3.
 */

import 'package:flutter/material.dart';
import 'package:flauncher/l10n/app_localizations.dart';
import 'pin_pad.dart';

/// Asks for a new 8-digit PIN twice (enter + confirm) and returns it once both
/// entries match, or null if cancelled.
Future<String?> showSetPinDialog(BuildContext context) {
  return showDialog<String>(context: context, builder: (_) => const _SetPinDialog());
}

class _SetPinDialog extends StatefulWidget {
  const _SetPinDialog();

  @override
  State<_SetPinDialog> createState() => _SetPinDialogState();
}

class _SetPinDialogState extends State<_SetPinDialog> {
  String? _first;
  String? _error;

  void _onCompleted(String code) {
    if (_first == null) {
      setState(() {
        _first = code;
        _error = null;
      });
    } else if (code == _first) {
      Navigator.of(context).pop(code);
    } else {
      final l = AppLocalizations.of(context)!;
      setState(() {
        _first = null;
        _error = l.hotelPinMismatch;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(_first == null ? l.hotelSetPin : l.hotelRepeatPin),
      content: SizedBox(
        width: 320,
        child: PinPad(
          // A new key forces a fresh, empty pad for the confirmation step.
          key: ValueKey(_first == null ? "enter" : "confirm"),
          onCompleted: _onCompleted,
          errorText: _error,
        ),
      ),
    );
  }
}

/*
 * Smotrim.CZ Launcher
 * Based on FLauncher (C) 2021 Étienne Fesser — GPLv3.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flauncher/l10n/app_localizations.dart';

/// Payment details for the Smotrim.CZ subscription.
class _Payment {
  static const String accountNumber = "2200198639 / 2010";
  static const String ibanDisplay = "CZ47 2010 0000 0022 0019 8639";
  static const String iban = "CZ4720100000002200198639";
  static const String bic = "FIOBCZPPXXX";
  static const String amount = "1000 Kč";
  static const String phone = "+420608210867";

  /// Czech "QR Platba" (SPAYD) string with the 1000 CZK amount embedded,
  /// so scanning it pre-fills the payment in the user's banking app.
  static const String spayd =
      "SPD*1.0*ACC:$iban+$bic*AM:1000.00*CC:CZK*MSG:SMOTRIM.CZ";
}

/// Focusable "Renew subscription" button shown among the apps on the home
/// screen. Opens a dialog with payment instructions and a QR code.
class SubscriptionButton extends StatefulWidget {
  const SubscriptionButton({super.key});

  @override
  State<SubscriptionButton> createState() => _SubscriptionButtonState();
}

class _SubscriptionButtonState extends State<SubscriptionButton> {
  bool _focused = false;

  void _open() {
    showDialog(
      context: context,
      builder: (_) => const SubscriptionDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final accent = Theme.of(context).colorScheme.primary;

    return Actions(
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _open()),
        ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(onInvoke: (_) => _open()),
      },
      child: Focus(
        onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
        child: AnimatedScale(
          scale: _focused ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: Material(
            color: _focused ? accent : accent.withOpacity(0.85),
            borderRadius: BorderRadius.circular(8),
            elevation: _focused ? 16 : 0,
            shadowColor: Colors.black,
            child: InkWell(
              onTap: _open,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: _focused
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.card_membership, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      localizations.renewSubscription,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog with subscription payment instructions and a QR Platba code.
class SubscriptionDialog extends StatelessWidget {
  const SubscriptionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(localizations.subscriptionDialogTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    Text(localizations.subscriptionScanToPay, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: QrImageView(
                        data: _Payment.spayd,
                        version: QrVersions.auto,
                        size: 200,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _row(context, localizations.subscriptionAmountLabel, _Payment.amount, bold: true),
              _row(context, localizations.subscriptionAccountLabel, _Payment.accountNumber),
              _row(context, localizations.subscriptionIbanLabel, _Payment.ibanDisplay),
              _row(context, localizations.subscriptionBicLabel, _Payment.bic),
              const Divider(height: 24),
              _note(context, Icons.qr_code_2, localizations.subscriptionBankNote),
              _note(context, Icons.schedule, localizations.subscriptionProcessingHours),
              _note(context, Icons.sms_outlined, localizations.subscriptionSmsConfirmation),
              _note(context, Icons.support_agent,
                  "${localizations.subscriptionContactLabel}: ${_Payment.phone}"),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(localizations.close),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value, {bool bold = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _note(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

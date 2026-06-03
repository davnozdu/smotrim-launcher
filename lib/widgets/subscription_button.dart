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

  /// Card payment link encoded into the QR on the "pay by card" page.
  // TODO: replace with the real card-payment URL.
  static const String cardPaymentUrl = "https://smotrim.cz/pay";

  /// Czech instant "QR Platba" (SPAYD) for the bank transfer. The payer's phone
  /// number is put into the MSG (message for recipient) field, and the payment
  /// type is set to instant (PT:IP).
  static String transferSpayd(String payerPhone) {
    final msg = payerPhone.replaceAll(RegExp(r'[*\s]'), '');
    return "SPD*1.0*ACC:$iban+$bic*AM:1000.00*CC:CZK*PT:IP*MSG:$msg";
  }
}

/// Focusable "Renew subscription" button shown on the home screen.
class SubscriptionButton extends StatefulWidget {
  const SubscriptionButton({super.key});

  @override
  State<SubscriptionButton> createState() => _SubscriptionButtonState();
}

class _SubscriptionButtonState extends State<SubscriptionButton> {
  bool _focused = false;

  void _open() => showDialog(context: context, builder: (_) => const SubscriptionDialog());

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
                  border: _focused ? Border.all(color: Colors.white, width: 2) : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.card_membership, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      localizations.renewSubscription,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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

enum _PayPage { menu, transfer, card }

/// Subscription dialog: a menu with two options (bank transfer / card), each
/// opening its own card. Fully navigable with the TV remote.
class SubscriptionDialog extends StatefulWidget {
  const SubscriptionDialog({super.key});

  @override
  State<SubscriptionDialog> createState() => _SubscriptionDialogState();
}

class _SubscriptionDialogState extends State<SubscriptionDialog> {
  _PayPage _page = _PayPage.menu;
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _goTo(_PayPage page) => setState(() => _page = page);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Dialog(
      insetPadding: const EdgeInsets.all(40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: FocusTraversalGroup(
            child: switch (_page) {
              _PayPage.menu => _menuPage(context, l),
              _PayPage.transfer => _transferPage(context, l),
              _PayPage.card => _cardPage(context, l),
            },
          ),
        ),
      ),
    );
  }

  // ---- Pages ---------------------------------------------------------------

  Widget _menuPage(BuildContext context, AppLocalizations l) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(context, l.subscriptionDialogTitle),
        const SizedBox(height: 20),
        _MenuButton(
          icon: Icons.account_balance,
          label: l.payByTransfer,
          autofocus: true,
          onPressed: () => _goTo(_PayPage.transfer),
        ),
        const SizedBox(height: 12),
        _MenuButton(
          icon: Icons.credit_card,
          label: l.payByCard,
          onPressed: () => _goTo(_PayPage.card),
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: _TextButtonFocusable(label: l.close, onPressed: () => Navigator.of(context).pop()),
        ),
      ],
    );
  }

  Widget _transferPage(BuildContext context, AppLocalizations l) {
    final spayd = _Payment.transferSpayd(_phoneController.text);
    return _scaffoldPage(
      context,
      l,
      title: l.payByTransfer,
      body: [
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: l.subscriptionYourPhone,
            prefixIcon: const Icon(Icons.phone),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        _qr(spayd),
        const SizedBox(height: 8),
        Center(child: Text(l.subscriptionScanToPay, style: Theme.of(context).textTheme.bodyMedium)),
        const SizedBox(height: 16),
        _row(context, l.subscriptionAmountLabel, _Payment.amount, bold: true),
        _row(context, l.subscriptionAccountLabel, _Payment.accountNumber),
        _row(context, l.subscriptionIbanLabel, _Payment.ibanDisplay),
        _row(context, l.subscriptionBicLabel, _Payment.bic),
        const Divider(height: 24),
        _note(context, Icons.schedule, l.subscriptionProcessingHours),
        _note(context, Icons.support_agent, "${l.subscriptionContactLabel}: ${_Payment.phone}"),
      ],
    );
  }

  Widget _cardPage(BuildContext context, AppLocalizations l) {
    return _scaffoldPage(
      context,
      l,
      title: l.payByCard,
      body: [
        _qr(_Payment.cardPaymentUrl),
        const SizedBox(height: 8),
        Center(child: Text(l.subscriptionScanToPay, style: Theme.of(context).textTheme.bodyMedium)),
        const SizedBox(height: 16),
        _note(context, Icons.info_outline, l.subscriptionCardPhoneNote),
        _note(context, Icons.schedule, l.subscriptionProcessingHours),
      ],
    );
  }

  // ---- Building blocks -----------------------------------------------------

  /// A page with a title, a scrollable body and a Back/Close footer.
  Widget _scaffoldPage(
    BuildContext context,
    AppLocalizations l, {
    required String title,
    required List<Widget> body,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(context, title),
        const SizedBox(height: 12),
        Flexible(
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _TextButtonFocusable(label: l.back, onPressed: () => _goTo(_PayPage.menu)),
            _TextButtonFocusable(label: l.close, onPressed: () => Navigator.of(context).pop()),
          ],
        ),
      ],
    );
  }

  Widget _title(BuildContext context, String text) =>
      Text(text, style: Theme.of(context).textTheme.titleLarge);

  Widget _qr(String data) => Center(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
          child: QrImageView(data: data, version: QrVersions.auto, size: 170, backgroundColor: Colors.white),
        ),
      );

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
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: bold ? FontWeight.bold : FontWeight.w500),
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

/// Large focusable menu button (remote-friendly).
class _MenuButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool autofocus;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.autofocus = false,
  });

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Actions(
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onPressed()),
        ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(onInvoke: (_) => widget.onPressed()),
      },
      child: Focus(
        autofocus: widget.autofocus,
        onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
        child: Material(
          color: _focused ? accent : accent.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _focused ? Colors.white : accent, width: 2),
              ),
              child: Row(
                children: [
                  Icon(widget.icon, color: Colors.white, size: 26),
                  const SizedBox(width: 14),
                  Text(widget.label, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Focusable text button used for Back/Close in the dialog footer.
class _TextButtonFocusable extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;

  const _TextButtonFocusable({required this.label, required this.onPressed});

  @override
  State<_TextButtonFocusable> createState() => _TextButtonFocusableState();
}

class _TextButtonFocusableState extends State<_TextButtonFocusable> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Actions(
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onPressed()),
        ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(onInvoke: (_) => widget.onPressed()),
      },
      child: Focus(
        onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: _focused ? accent.withOpacity(0.25) : Colors.transparent,
              border: Border.all(color: _focused ? accent : Colors.transparent, width: 2),
            ),
            child: Text(widget.label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}

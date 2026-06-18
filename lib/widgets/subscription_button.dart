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
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/providers/settings_service.dart';

/// Payment details for the Smotrim.CZ subscription.
class _Payment {
  static const String accountNumber = "2200198639 / 2010";
  static const String ibanDisplay = "CZ47 2010 0000 0022 0019 8639";
  static const String iban = "CZ4720100000002200198639";
  static const String bic = "FIOBCZPPXXX";
  static const String phone = "+420608210867";

  /// Card payment links encoded into the QR on the "pay by card" page.
  static const String renewCardUrl = "https://pay.sumup.com/b2c/QZFA9XAV";
  static const String becomeCardUrl = "https://pay.sumup.com/b2c/Q2W3D0TB";

  /// Czech instant "QR Platba" (SPAYD) for the bank transfer. The subscriber ID
  /// goes into the X-VS (variabilní symbol) field so the payment is matched
  /// automatically; the PIN, email and phone go into the MSG (message) note.
  /// Payment type is instant (PT:IP).
  static String transferSpayd({
    required String payerPhone,
    required String subscriberId,
    required String amountSpayd,
    String email = '',
    String pin = '',
  }) {
    final id = subscriberId.replaceAll(RegExp(r'\D'), ''); // VS = digits only
    final phone = payerPhone.replaceAll(RegExp(r'[*\s]'), '');
    final mail = email.replaceAll(RegExp(r'[*\s]'), '');
    final pinClean = pin.replaceAll(RegExp(r'\D'), '');
    final msg = [
      if (id.isNotEmpty) 'ID:$id',
      if (pinClean.isNotEmpty) 'PIN:$pinClean',
      if (mail.isNotEmpty) 'Email:$mail',
      if (phone.isNotEmpty) 'Tel:$phone',
    ].join(' ');
    final vsPart = id.isEmpty ? '' : '*X-VS:$id';
    final msgPart = msg.isEmpty ? '' : '*MSG:$msg';
    return "SPD*1.0*ACC:$iban+$bic*AM:$amountSpayd*CC:CZK*PT:IP$vsPart$msgPart";
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
          // Anchor the zoom to the left edge so the focused button grows to the
          // right instead of spilling past the left screen margin.
          alignment: Alignment.centerLeft,
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

/// Focusable "Become a subscriber" button shown on the home screen. Red, so it
/// stands out from the purple "renew" button. Opens the subscription dialog in
/// "become" mode (2800 Kč, the device's permanent ID + PIN).
class BecomeSubscriberButton extends StatefulWidget {
  const BecomeSubscriberButton({super.key});

  @override
  State<BecomeSubscriberButton> createState() => _BecomeSubscriberButtonState();
}

class _BecomeSubscriberButtonState extends State<BecomeSubscriberButton> {
  bool _focused = false;

  void _open() => showDialog(
        context: context,
        builder: (_) => const SubscriptionDialog(becomeSubscriber: true),
      );

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    const red = Color(0xFFD32F2F); // Colors.red.shade700

    return Actions(
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _open()),
        ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(onInvoke: (_) => _open()),
      },
      child: Focus(
        onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
        child: AnimatedScale(
          scale: _focused ? 1.04 : 1.0,
          alignment: Alignment.centerLeft,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: Material(
            color: _focused ? red : red.withOpacity(0.85),
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
                    const Icon(Icons.how_to_reg, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      localizations.becomeSubscriber,
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
  // false = "Renew subscription" (existing subscriber, 1000 Kč, manual ID).
  // true  = "Become a subscriber" (new: 2800 Kč, the device's permanent ID+PIN
  //         from [SettingsService], activation note).
  final bool becomeSubscriber;
  const SubscriptionDialog({super.key, this.becomeSubscriber = false});

  @override
  State<SubscriptionDialog> createState() => _SubscriptionDialogState();
}

class _SubscriptionDialogState extends State<SubscriptionDialog> {
  _PayPage _page = _PayPage.menu;
  String _phone = "";
  String _id = "";
  String _pin = "";
  String _email = "";
  final ScrollController _scrollController = ScrollController();

  bool get _become => widget.becomeSubscriber;
  String get _amountDisplay => _become ? '2800 Kč' : '1000 Kč';
  String get _amountSpayd => _become ? '2800.00' : '1000.00';
  String get _cardUrl => _become ? _Payment.becomeCardUrl : _Payment.renewCardUrl;

  @override
  void initState() {
    super.initState();
    if (_become) {
      // New subscriber: use this device's permanent, generated-once ID + PIN.
      final settings = context.read<SettingsService>();
      _id = settings.subscriberId;
      _pin = settings.subscriberPin;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _goTo(_PayPage page) {
    // Reset the scroll offset so each page opens from the top.
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    setState(() => _page = page);
  }

  // D-pad handling for the payment pages: first try to move focus between the
  // focusable buttons; if there is nothing focusable further in that direction
  // (e.g. the read-only header, QR or notes), scroll the page instead — so the
  // user can always go back up to see the activation note / ID / PIN.
  KeyEventResult _handleScrollKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final TraversalDirection? dir = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp => TraversalDirection.up,
      LogicalKeyboardKey.arrowDown => TraversalDirection.down,
      _ => null,
    };
    if (dir == null) return KeyEventResult.ignored;
    final moved = FocusManager.instance.primaryFocus?.focusInDirection(dir) ?? false;
    if (moved) return KeyEventResult.handled;
    if (!_scrollController.hasClients) return KeyEventResult.handled;
    final pos = _scrollController.position;
    final target = (_scrollController.offset + (dir == TraversalDirection.down ? 140.0 : -140.0))
        .clamp(0.0, pos.maxScrollExtent);
    _scrollController.animateTo(target, duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
    return KeyEventResult.handled;
  }

  Future<void> _editPhone() async {
    final l = AppLocalizations.of(context)!;
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _TextInputDialog(
        title: l.subscriptionYourPhone,
        initial: _phone,
        icon: Icons.phone,
        keyboardType: TextInputType.phone,
      ),
    );
    if (result != null && mounted) setState(() => _phone = result.trim());
  }

  Future<void> _editEmail() async {
    final l = AppLocalizations.of(context)!;
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _TextInputDialog(
        title: l.yourEmail,
        initial: _email,
        icon: Icons.email,
        keyboardType: TextInputType.emailAddress,
      ),
    );
    if (result != null && mounted) setState(() => _email = result.trim());
  }

  Future<void> _editId() async {
    final l = AppLocalizations.of(context)!;
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _TextInputDialog(
        title: l.subscriptionYourId,
        initial: _id,
        icon: Icons.badge,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(8),
        ],
      ),
    );
    if (result != null && mounted) setState(() => _id = result.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Dialog(
      insetPadding: const EdgeInsets.all(40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
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
        _title(context, _become ? l.becomeSubscriber : l.subscriptionDialogTitle),
        const SizedBox(height: 16),
        if (_become) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(l.becomeMenuNote, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(height: 16),
        ],
        _MenuButton(icon: Icons.account_balance, label: l.payByTransfer, autofocus: true, onPressed: () => _goTo(_PayPage.transfer)),
        const SizedBox(height: 12),
        _MenuButton(icon: Icons.credit_card, label: l.payByCard, onPressed: () => _goTo(_PayPage.card)),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: _TextButtonFocusable(label: l.close, onPressed: () => Navigator.of(context).pop()),
        ),
      ],
    );
  }

  Widget _transferPage(BuildContext context, AppLocalizations l) {
    final spayd = _Payment.transferSpayd(
      payerPhone: _phone,
      subscriberId: _id,
      email: _email,
      amountSpayd: _amountSpayd,
      pin: _become ? _pin : '',
    );
    return _scrollPage(
      context,
      title: l.payByTransfer,
      body: [
        if (_become) ..._becomeHeader(context, l),
        _MenuButton(
          icon: Icons.phone,
          label: _phone.isEmpty ? l.subscriptionYourPhone : _phone,
          onPressed: _editPhone,
        ),
        const SizedBox(height: 12),
        // Renew: the ID is entered manually. Become: it is the device's
        // permanent ID, shown read-only in the header above.
        if (!_become) ...[
          _MenuButton(
            icon: Icons.badge,
            label: _id.isEmpty ? l.subscriptionYourId : _id,
            onPressed: _editId,
          ),
          const SizedBox(height: 12),
        ],
        _MenuButton(
          icon: Icons.email,
          label: _email.isEmpty ? l.yourEmail : _email,
          onPressed: _editEmail,
        ),
        const SizedBox(height: 16),
        _row(context, l.subscriptionAmountLabel, _amountDisplay, bold: true),
        _row(context, l.subscriptionAccountLabel, _Payment.accountNumber),
        _row(context, l.subscriptionIbanLabel, _Payment.ibanDisplay),
        _row(context, l.subscriptionBicLabel, _Payment.bic),
        const SizedBox(height: 12),
        _qr(spayd),
        const SizedBox(height: 8),
        Center(child: Text(l.subscriptionScanToPay, style: Theme.of(context).textTheme.bodyMedium)),
        const Divider(height: 24),
        _note(context, Icons.schedule, l.subscriptionProcessingHours),
        _note(context, Icons.support_agent, "${l.subscriptionContactLabel}: ${_Payment.phone}"),
      ],
      footer: [
        _TextButtonFocusable(label: l.back, onPressed: () => _goTo(_PayPage.menu)),
        _TextButtonFocusable(label: l.close, onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }

  Widget _cardPage(BuildContext context, AppLocalizations l) {
    return _scrollPage(
      context,
      title: l.payByCard,
      body: [
        if (_become) ..._becomeHeader(context, l),
        _qr(_cardUrl),
        const SizedBox(height: 8),
        Center(child: Text(l.subscriptionScanToPay, style: Theme.of(context).textTheme.bodyMedium)),
        const SizedBox(height: 12),
        if (!_become) _row(context, l.subscriptionYourId, _id),
        _note(context, Icons.percent, l.subscriptionCardCommission),
        _note(context, Icons.info_outline, l.subscriptionCardPhoneNote),
        _note(context, Icons.schedule, l.subscriptionProcessingHours),
      ],
      footer: [
        _TextButtonFocusable(label: l.back, onPressed: () => _goTo(_PayPage.menu)),
        _TextButtonFocusable(label: l.close, onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }

  // Header shown only for "become a subscriber": the device's permanent ID and
  // PIN (read-only) plus a reminder to save them.
  List<Widget> _becomeHeader(BuildContext context, AppLocalizations l) {
    return [
      _row(context, l.subscriptionYourId, _id, bold: true),
      _row(context, l.yourPin, _pin, bold: true),
      _note(context, Icons.save_alt, l.becomeSaveCredentials),
      const SizedBox(height: 8),
    ];
  }

  // ---- Building blocks -----------------------------------------------------

  /// A page with a title and a single scroll view that contains the body AND
  /// the footer buttons. The D-pad scrolls past read-only content (see
  /// [_handleScrollKey]) so the user can always return to the top.
  Widget _scrollPage(
    BuildContext context, {
    required String title,
    required List<Widget> body,
    required List<Widget> footer,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(context, title),
        const SizedBox(height: 12),
        Flexible(
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: _handleScrollKey,
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...body,
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: footer),
                ],
              ),
            ),
          ),
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
          child: QrImageView(data: data, version: QrVersions.auto, size: 160, backgroundColor: Colors.white),
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
            child: Text(
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

/// Modal that collects a single text value (phone / email / subscriber ID).
/// Escapable via the keyboard's "done" action (pops with the value), the OK
/// button, or Back.
class _TextInputDialog extends StatefulWidget {
  final String title;
  final String initial;
  final IconData icon;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _TextInputDialog({
    required this.title,
    required this.initial,
    required this.icon,
    required this.keyboardType,
    this.inputFormatters,
  });

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // On the TV box the soft keyboard only opens on a tap/focus push.
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        SystemChannels.textInput.invokeMethod('TextInput.show');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true,
        keyboardType: widget.keyboardType,
        inputFormatters: widget.inputFormatters,
        textInputAction: TextInputAction.done,
        onSubmitted: (value) => Navigator.of(context).pop(value),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(widget.icon),
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        _TextButtonFocusable(label: l.close, onPressed: () => Navigator.of(context).pop()),
        _TextButtonFocusable(label: l.save, onPressed: () => Navigator.of(context).pop(_controller.text)),
      ],
    );
  }
}

/// Large focusable menu button (remote-friendly).
class _MenuButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool autofocus;

  const _MenuButton({required this.icon, required this.label, required this.onPressed, this.autofocus = false});

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
        onFocusChange: (hasFocus) {
          setState(() => _focused = hasFocus);
          if (hasFocus) Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 150));
        },
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
                  Expanded(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Focusable text button used for Back/Close/OK (remote-friendly).
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
        onFocusChange: (hasFocus) {
          setState(() => _focused = hasFocus);
          if (hasFocus) Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 150));
        },
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

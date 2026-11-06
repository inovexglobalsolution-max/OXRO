import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:oxro_pricing/oxro_pricing.dart';

import 'package:oxro/app/repositories/smart_change_repo.dart';

const Color _ckAccent = Color(0xFFFF6A00);
const Color _ckInk = Color(0xFF102A43);
const Color _ckLine = Color(0xFFE5EBF2);
const Color _ckTint = Color(0xFFFFF7F1);
const Color _ckGreen = Color(0xFF1B9E52);

/// Result returned by [CodSmartChangeDialog].
class CodSmartChangeResult {
  const CodSmartChangeResult({
    required this.confirmed,
    this.cashAmountPaise,
    this.txnId,
    this.walletCreditPaise,
  });

  /// Whether the customer activated Smart Change (server-confirmed).
  final bool confirmed;

  /// Cash amount the customer will hand over (paise).
  final int? cashAmountPaise;

  /// Server transaction id of the activated consent.
  final String? txnId;

  /// Exact wallet credit calculated server-side (paise).
  final int? walletCreditPaise;

  /// Declined / dismissed — COD must not be selected.
  static const declined = CodSmartChangeResult(confirmed: false);
}

enum _Step { consent, entry, confirm, success }

/// OXRO Smart Change — mandatory COD confirmation flow.
///
/// Step 1: consent popup (YES, I AGREE / NO, CANCEL ORDER).
/// Step 2: cash amount entry with live wallet-credit calculation.
/// Step 3: final confirmation (server activation, no fake success).
/// Step 4: green success tick, then auto-pop with the result.
class CodSmartChangeDialog extends StatefulWidget {
  const CodSmartChangeDialog({
    super.key,
    required this.orderAmountPaise,
    this.initialCashPaise,
  });

  final int orderAmountPaise;

  /// Pre-filled cash amount when re-confirming (paise).
  final int? initialCashPaise;

  @override
  State<CodSmartChangeDialog> createState() => _CodSmartChangeDialogState();
}

class _CodSmartChangeDialogState extends State<CodSmartChangeDialog> {
  late final TextEditingController _ctrl;
  late final String _idempotencyKey;
  _Step _step = _Step.consent;
  bool _submitting = false;
  String? _error;
  int? _cashPaise;
  SmartChangeActivation? _activation;

  int get _orderPaise => widget.orderAmountPaise;

  @override
  void initState() {
    super.initState();
    _idempotencyKey = SmartChangeRepo.newIdempotencyKey();
    _ctrl = TextEditingController(
      text: widget.initialCashPaise == null
          ? ''
          : (widget.initialCashPaise! / 100).toStringAsFixed(
              widget.initialCashPaise! % 100 == 0 ? 0 : 2,
            ),
    );
    _ctrl.addListener(_onCashChanged);
    _onCashChanged();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onCashChanged() {
    final t = _ctrl.text.trim();
    final rupees = double.tryParse(t);
    final valid = rupees != null && rupees > 0;
    setState(() {
      _cashPaise = valid ? (rupees * 100).round() : null;
    });
  }

  bool get _cashValid => _cashPaise != null && _cashPaise! >= _orderPaise;
  bool get _insufficient => _cashPaise != null && _cashPaise! < _orderPaise;
  bool get _exactCash => _cashPaise != null && _cashPaise == _orderPaise;
  int? get _changePaise =>
      _cashPaise == null ? null : _cashPaise! - _orderPaise;

  String _money(int paise) => Money.inr(paise);

  Future<void> _confirm() async {
    if (_submitting || _cashPaise == null || !_cashValid) return;
    HapticFeedback.selectionClick();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final activation = await SmartChangeRepo.instance.activate(
        orderAmountPaise: _orderPaise,
        cashAmountPaise: _cashPaise!,
        customerId: SmartChangeRepo.currentCustomerId,
        idempotencyKey: _idempotencyKey,
      );
      if (!mounted) return;
      setState(() {
        _activation = activation;
        _submitting = false;
        _step = _Step.success;
      });
      // Show the success tick, then hand the result back.
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) Navigator.of(context).pop(_successResult());
      });
    } on SmartChangeException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    } on TimeoutException {
      if (!mounted) return;
      debugPrint('Smart Change activate: timeout');
      setState(() {
        _submitting = false;
        _error =
            'OXRO Smart Change server is not responding. Check that the '
            'backend is running and try again.';
      });
    } catch (e, st) {
      debugPrint('Smart Change activate failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Could not reach OXRO Smart Change. Please try again.';
      });
    }
  }

  CodSmartChangeResult _successResult() {
    final a = _activation;
    return CodSmartChangeResult(
      confirmed: true,
      cashAmountPaise: _cashPaise,
      txnId: a?.txnId,
      walletCreditPaise: a?.remainingChangePaise ?? _changePaise ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const ValueKey('cod_smart_change'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: switch (_step) {
            _Step.consent => _consentStep(),
            _Step.entry => _entryStep(context),
            _Step.confirm => _confirmStep(context),
            _Step.success => _successStep(context),
          },
        ),
      ),
    );
  }

  // ── Step 1: consent ────────────────────────────────────────────────
  Widget _consentStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '💰 OXRO Smart Change',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: _ckInk,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Make your COD payment easier with OXRO Smart Change!\n\n'
          'If you pay more than your order amount, your remaining change '
          'will be automatically credited to your OXRO Wallet.\n\n'
          'No physical change will be returned by the delivery partner.\n\n'
          'Please enter the cash amount you plan to pay and confirm that '
          'you agree to receive your remaining change in your OXRO Wallet.',
          style: TextStyle(fontSize: 13.5, height: 1.45, color: _ckInk),
        ),
        const SizedBox(height: 20),
        FilledButton(
          key: const ValueKey('sc_agree'),
          style: FilledButton.styleFrom(
            backgroundColor: _ckAccent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: () => setState(() => _step = _Step.entry),
          child: const Text(
            'YES, I AGREE',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          key: const ValueKey('sc_cancel'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: () =>
              Navigator.of(context).pop(CodSmartChangeResult.declined),
          child: const Text(
            'NO, CANCEL ORDER',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
        ),
      ],
    );
  }

  // ── Step 2: cash entry ─────────────────────────────────────────────
  Widget _entryStep(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'How much cash are you going to pay?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: _ckInk,
          ),
        ),
        const SizedBox(height: 14),
        _amountRow('Order Amount', _money(_orderPaise)),
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('cod_cash_input'),
          controller: _ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(
            labelText: 'Cash Amount you will pay',
            prefixText: '₹ ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        if (_cashPaise != null) ...[
          const SizedBox(height: 12),
          _amountRow('Cash Amount', _money(_cashPaise!)),
          const SizedBox(height: 6),
          _amountRow(
            'Remaining Change',
            _money(_changePaise ?? 0),
            highlight: true,
          ),
          const SizedBox(height: 6),
          _amountRow(
            'OXRO Wallet Credit',
            _money(_changePaise ?? 0),
            highlight: true,
          ),
        ],
        if (_exactCash) ...[
          const SizedBox(height: 10),
          Container(
            key: const ValueKey('cod_exact_cash'),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _ckGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _ckGreen),
            ),
            child: const Text(
              'Exact Cash — no wallet credit needed.',
              style: TextStyle(color: _ckGreen, fontWeight: FontWeight.w700),
            ),
          ),
        ],
        if (_insufficient) ...[
          const SizedBox(height: 12),
          Container(
            key: const ValueKey('cod_change_insufficient'),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red),
            ),
            child: Text(
              'Insufficient Cash — cash must be equal to or greater than '
              'the order amount (${_money(_orderPaise)}).',
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        FilledButton(
          key: const ValueKey('sc_continue'),
          style: FilledButton.styleFrom(
            backgroundColor: _ckAccent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: _cashValid
              ? () => setState(() => _step = _Step.confirm)
              : null,
          child: const Text(
            'CONTINUE',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const ValueKey('sc_back'),
          onPressed: () => setState(() => _step = _Step.consent),
          child: const Text('Back'),
        ),
      ],
    );
  }

  // ── Step 3: final confirmation ─────────────────────────────────────
  Widget _confirmStep(BuildContext context) {
    final change = _changePaise ?? 0;
    final hasChange = change > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Confirm Smart Change',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: _ckInk,
          ),
        ),
        const SizedBox(height: 14),
        _amountRow('Order Amount', _money(_orderPaise)),
        const SizedBox(height: 8),
        _amountRow('Cash Amount', _money(_cashPaise ?? 0)),
        const SizedBox(height: 8),
        _amountRow('Remaining Change', _money(change)),
        const SizedBox(height: 8),
        _amountRow('Wallet Credit Amount', _money(change), highlight: true),
        const SizedBox(height: 14),
        Text(
          hasChange
              ? 'Your remaining ${_money(change)} will be credited to your '
                    'OXRO Money Wallet. Do you want to continue?'
              : 'You are paying exact cash. No wallet credit will be '
                    'made.\n\nNo physical change will be provided.',
          style: const TextStyle(fontSize: 13, height: 1.45, color: _ckInk),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            key: const ValueKey('sc_error'),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red),
            ),
            child: Text(
              _error!,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        FilledButton(
          key: const ValueKey('sc_confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: _ckAccent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: _submitting ? null : _confirm,
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  hasChange ? 'YES, ADD TO WALLET' : 'CONFIRM SMART CHANGE',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
        ),
        const SizedBox(height: 8),
        if (hasChange)
          OutlinedButton(
            key: const ValueKey('sc_confirm_cancel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _submitting
                ? null
                : () =>
                      Navigator.of(context).pop(CodSmartChangeResult.declined),
            child: const Text(
              'NO, CANCEL ORDER',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
          )
        else
          TextButton(
            key: const ValueKey('sc_back'),
            onPressed: _submitting
                ? null
                : () => setState(() => _step = _Step.entry),
            child: const Text('Back'),
          ),
      ],
    );
  }

  // ── Step 4: success ────────────────────────────────────────────────
  Widget _successStep(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final change = _changePaise ?? 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Center(
          child: TweenAnimationBuilder<double>(
            key: const ValueKey('sc_success_tick'),
            tween: Tween(begin: reduce ? 1 : 0, end: 1),
            duration: reduce
                ? Duration.zero
                : const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (context, v, child) =>
                Transform.scale(scale: v, child: child),
            child: Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: _ckGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 44, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'OXRO Smart Change Activated Successfully!',
          key: ValueKey('sc_success_text'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: _ckInk,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${_money(change)} will be credited to your OXRO Wallet '
          'after COD verification.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: _ckInk),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _amountRow(String label, String value, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight ? _ckTint : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlight ? _ckAccent : _ckLine),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: highlight ? _ckAccent : _ckInk,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: highlight ? _ckAccent : _ckInk,
            ),
          ),
        ],
      ),
    );
  }
}

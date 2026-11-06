import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:oxro_pricing/oxro_pricing.dart';

import 'package:oxro/app/repositories/smart_change_repo.dart';
import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';

/// Delivery partner — OXRO Smart Change COD collection.
///
/// Opened with a [txnId] (detail) or without (list of collectable orders).
/// The backend verifies the collected cash and credits the change to the
/// customer's OXRO Money Wallet; on credit failure the partner is told to
/// return the physical change / follow the support process.
class RiderCodCollectScreen extends StatefulWidget {
  const RiderCodCollectScreen({super.key, this.txnId});

  /// Specific Smart Change transaction to collect; null → list mode.
  final String? txnId;

  @override
  State<RiderCodCollectScreen> createState() => _RiderCodCollectScreenState();
}

class _RiderCodCollectScreenState extends State<RiderCodCollectScreen> {
  List<SmartChangeActivation> _pending = const [];
  SmartChangeActivation? _txn;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  String? _successMessage;
  late final TextEditingController _cashCtrl;

  @override
  void initState() {
    super.initState();
    _cashCtrl = TextEditingController();
    // Rebuild on text change so the Confirm gating stays live.
    _cashCtrl.addListener(() => setState(() {}));
    if (widget.txnId != null) {
      _loadTxn();
    } else {
      _loadList();
    }
  }

  @override
  void dispose() {
    _cashCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadList() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await SmartChangeRepo.instance.collectable();
      if (!mounted) return;
      setState(() {
        _pending = list;
        _loading = false;
      });
    } on SmartChangeException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not reach OXRO Smart Change. Please try again.';
      });
    }
  }

  Future<void> _loadTxn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final t = await SmartChangeRepo.instance.get(widget.txnId!);
      if (!mounted) return;
      setState(() {
        _txn = t;
        _cashCtrl.text = (t.cashAmountPaise / 100).toStringAsFixed(
          t.cashAmountPaise % 100 == 0 ? 0 : 2,
        );
        _loading = false;
      });
    } on SmartChangeException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not reach OXRO Smart Change. Please try again.';
      });
    }
  }

  int? get _actualCashPaise {
    final rupees = double.tryParse(_cashCtrl.text.trim());
    if (rupees == null || rupees <= 0) return null;
    return (rupees * 100).round();
  }

  bool get _cashValid {
    final paise = _actualCashPaise;
    return paise != null && paise >= (_txn?.orderAmountPaise ?? 0);
  }

  Future<void> _confirmCollected() async {
    final txn = _txn;
    if (_submitting || txn == null || !_cashValid) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _submitting = true;
      _error = null;
      _successMessage = null;
    });
    try {
      final result = await SmartChangeRepo.instance.collect(
        txnId: txn.txnId,
        actualCashPaise: _actualCashPaise!,
        partnerId: 'partner-rider',
      );
      if (!mounted) return;
      setState(() {
        _txn = result;
        _submitting = false;
        _successMessage =
            '${Money.inr(result.remainingChangePaise)} change credited to '
            'the customer\'s OXRO Money Wallet.';
      });
    } on SmartChangeException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error =
            '${e.message}\n\nReturn the physical change to the '
            'customer or follow the approved OXRO support process.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error =
            'Cash verification failed — return the physical change to '
            'the customer or contact OXRO support.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF102A43)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Smart Change COD',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 17,
            color: Color(0xFF102A43),
          ),
        ),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _txn == null
          ? _errorState()
          : widget.txnId == null
          ? _listState()
          : _detailState(),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 44,
              color: Colors.red,
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('rider_sc_retry'),
              style: FilledButton.styleFrom(
                backgroundColor: OxroColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              onPressed: widget.txnId == null ? _loadList : _loadTxn,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listState() {
    if (_pending.isEmpty) {
      return Center(
        child: Text(
          'No pending Smart Change COD collections',
          key: const ValueKey('rider_sc_empty'),
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: OxroColors.muted,
          ),
        ),
      );
    }
    return ListView(
      key: const ValueKey('rider_sc_list'),
      padding: EdgeInsets.fromLTRB(context.padX, 12, context.padX, 24),
      children: [for (final t in _pending) _listCard(t)],
    );
  }

  Widget _listCard(SmartChangeActivation t) {
    return Container(
      key: ValueKey('rider_sc_card_${t.txnId}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(context.rs(14)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OxroColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.orderId?.isNotEmpty == true ? t.orderId! : t.txnId,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: OxroColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'COD',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: OxroColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _amountRow('Order Amount', Money.inr(t.orderAmountPaise)),
          _amountRow('Declared Cash', Money.inr(t.cashAmountPaise)),
          _amountRow(
            'Expected Change',
            Money.inr(t.remainingChangePaise),
            highlight: true,
          ),
          const SizedBox(height: 10),
          GestureDetector(
            key: ValueKey('rider_sc_open_${t.txnId}'),
            behavior: HitTestBehavior.opaque,
            onTap: () =>
                pushScreen(context, RiderCodCollectScreen(txnId: t.txnId)),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: OxroColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Open collection',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailState() {
    final txn = _txn;
    if (txn == null) return _errorState();
    return ListView(
      key: const ValueKey('rider_sc_detail'),
      padding: EdgeInsets.fromLTRB(context.padX, 12, context.padX, 24),
      children: [
        Container(
          padding: EdgeInsets.all(context.rs(16)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: OxroColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                txn.orderId?.isNotEmpty == true
                    ? 'Order ${txn.orderId}'
                    : 'Transaction ${txn.txnId}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF102A43),
                ),
              ),
              const SizedBox(height: 12),
              _amountRow('Order Amount', Money.inr(txn.orderAmountPaise)),
              _amountRow(
                'Customer Declared Cash',
                Money.inr(txn.cashAmountPaise),
              ),
              _amountRow(
                'Expected Change',
                Money.inr(txn.remainingChangePaise),
                highlight: true,
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('rider_sc_cash_input'),
                controller: _cashCtrl,
                enabled: !_submitting && _successMessage == null,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Actual cash collected',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (_successMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  key: const ValueKey('rider_sc_success'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: OxroColors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: OxroColors.green),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: OxroColors.green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: OxroColors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  key: const ValueKey('rider_sc_error'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.red,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey('rider_sc_confirm'),
                style: FilledButton.styleFrom(
                  backgroundColor: OxroColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed:
                    _submitting ||
                        _successMessage != null ||
                        !_cashValid ||
                        _cashCtrl.text.trim().isEmpty
                    ? null
                    : _confirmCollected,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Confirm Cash Collected',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _amountRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: highlight ? OxroColors.primary : OxroColors.muted,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: highlight ? OxroColors.primary : OxroColors.charcoal,
            ),
          ),
        ],
      ),
    );
  }
}

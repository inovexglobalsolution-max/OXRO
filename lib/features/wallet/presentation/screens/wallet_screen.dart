import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/oxro_snack.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/wallet/data/wallet_store.dart';

/// OXRO Wallet — balance + mock top-up + ledger.
/// All mock / in-memory; backend ledger replaces later.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _amtCtrl = TextEditingController();

  @override
  void dispose() {
    _amtCtrl.dispose();
    super.dispose();
  }

  void _add(int amount) {
    if (amount <= 0) return;
    WalletStore.instance.add(amount);
    _amtCtrl.clear();
    FocusScope.of(context).unfocus();
    showOxroSnack(context, '${Product.inr(amount)} added to wallet');
  }

  void _addCustom() {
    final v = int.tryParse(_amtCtrl.text.trim()) ?? 0;
    if (v < 10) {
      showOxroSnack(context, 'Enter at least ₹10');
      return;
    }
    if (v > 50000) {
      showOxroSnack(context, 'Max ₹50,000 per top-up in demo');
      return;
    }
    _add(v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: context.rs(8), vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () =>
                        Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back,
                        color: OxroColors.charcoal),
                  ),
                  Expanded(
                    child: Text('Wallet',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: context.font(17),
                            fontWeight: FontWeight.w800,
                            color: OxroColors.charcoal)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: WalletStore.instance,
                builder: (context, _) {
                  final store = WalletStore.instance;
                  return ListView(
                    key: const ValueKey('wallet_scroll'),
                    padding: EdgeInsets.fromLTRB(
                        context.padX, 6, context.padX, 20),
                    children: [
                      Container(
                        key: const ValueKey('wallet_balance'),
                        padding: EdgeInsets.all(context.rs(16)),
                        decoration: BoxDecoration(
                          gradient: OxroColors.gradient,
                          borderRadius:
                              BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: OxroColors.primary
                                  .withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text('OXRO Balance',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(Product.inr(store.balance),
                                style: TextStyle(
                                    fontSize: context.font(28),
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                            const SizedBox(height: 4),
                            const Text(
                                'Use at checkout • No expiry in demo',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white70)),
                          ],
                        ),
                      ),
                      SizedBox(height: context.rs(12)),
                      Row(
                        children: [
                          for (final a in [100, 500, 1000])
                            Expanded(
                              child: GestureDetector(
                                key: ValueKey('wallet_add_$a'),
                                onTap: () => _add(a),
                                behavior:
                                    HitTestBehavior.opaque,
                                child: Container(
                                  margin: EdgeInsets.only(
                                      right: a == 1000
                                          ? 0
                                          : 8),
                                  padding:
                                      const EdgeInsets.symmetric(
                                          vertical: 11),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(
                                            12),
                                    border: Border.all(
                                        color: OxroColors
                                            .primary),
                                  ),
                                  child: Text(
                                      '+${Product.inr(a)}',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight:
                                              FontWeight.w800,
                                          color: OxroColors
                                              .primary)),
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: context.rs(10)),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: const ValueKey(
                                  'wallet_amount'),
                              controller: _amtCtrl,
                              keyboardType:
                                  TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter
                                    .digitsOnly
                              ],
                              textInputAction:
                                  TextInputAction.done,
                              onSubmitted: (_) =>
                                  _addCustom(),
                              decoration: InputDecoration(
                                hintText:
                                    'Custom amount (₹10–₹50,000)',
                                hintStyle: const TextStyle(
                                    color: OxroColors.muted,
                                    fontSize: 13),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 13),
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                          12),
                                  borderSide:
                                      const BorderSide(
                                          color: OxroColors
                                              .border),
                                ),
                                enabledBorder:
                                    OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                          12),
                                  borderSide:
                                      const BorderSide(
                                          color: OxroColors
                                              .border),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            key: const ValueKey(
                                'wallet_add_custom'),
                            onTap: _addCustom,
                            behavior:
                                HitTestBehavior.opaque,
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 13),
                              decoration: BoxDecoration(
                                color: OxroColors.primary,
                                borderRadius:
                                    BorderRadius.circular(
                                        12),
                              ),
                              child: const Text('Add',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight:
                                          FontWeight.w800)),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: context.rs(14)),
                      const Text('Transactions',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: OxroColors.charcoal)),
                      SizedBox(height: context.rs(8)),
                      if (store.txs.isEmpty)
                        Container(
                          key: const ValueKey(
                              'wallet_empty'),
                          padding:
                              const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color:
                                    OxroColors.border),
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                          child: const Text(
                              'No transactions yet — top up to get started',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: OxroColors.muted)),
                        )
                      else
                        for (final t in store.txs)
                          Container(
                            key: ValueKey(
                                'wallet_tx_${t.id}'),
                            margin: EdgeInsets.only(
                                bottom: context.rs(8)),
                            padding: EdgeInsets.all(
                                context.rs(12)),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color:
                                      OxroColors.border),
                              borderRadius:
                                  BorderRadius.circular(
                                      14),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  alignment:
                                      Alignment.center,
                                  decoration: BoxDecoration(
                                    color: (t.amount >= 0
                                            ? Colors.green
                                            : OxroColors
                                                .primary)
                                        .withValues(
                                            alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                      t.amount >= 0
                                          ? Icons
                                              .add_circle_outline
                                          : Icons
                                              .remove_circle_outline,
                                      size: 20,
                                      color: t.amount >= 0
                                          ? Colors.green
                                              .shade700
                                          : OxroColors
                                              .primary),
                                ),
                                SizedBox(
                                    width:
                                        context.rs(10)),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: [
                                      Text(t.label,
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow
                                                  .ellipsis,
                                          style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight:
                                                  FontWeight
                                                      .w700)),
                                      Text(
                                          '${t.date.day}/${t.date.month} • ${t.date.hour.toString().padLeft(2, '0')}:${t.date.minute.toString().padLeft(2, '0')}',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: OxroColors
                                                  .muted)),
                                    ],
                                  ),
                                ),
                                Text(
                                    '${t.amount >= 0 ? '+' : ''}${Product.inr(t.amount)}',
                                    style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight:
                                            FontWeight.w800,
                                        color: t.amount >=
                                                0
                                            ? Colors.green
                                                .shade700
                                            : OxroColors
                                                .charcoal)),
                              ],
                            ),
                          ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

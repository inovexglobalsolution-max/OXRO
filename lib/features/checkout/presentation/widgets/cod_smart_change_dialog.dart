import 'package:flutter/material.dart';

const Color _ckAccent = Color(0xFFFF6A00);
const Color _ckInk = Color(0xFF102A43);

const Color _ckLine = Color(0xFFE5EBF2);
const Color _ckTint = Color(0xFFFFF7F1);

/// Result returned by [CodSmartChangeDialog].
class CodSmartChangeResult {
  const CodSmartChangeResult({
    required this.cashAmount,
    required this.preference,
    required this.confirmed,
  });

  /// Cash amount entered (rupees). Null if dismissed/invalid.
  final double? cashAmount;

  /// 'wallet' or 'physical' for extra cash; null otherwise.
  final String? preference;

  /// Whether user confirmed to continue.
  final bool confirmed;
}

class CodSmartChangeDialog extends StatefulWidget {
  const CodSmartChangeDialog({
    super.key,
    required this.orderAmountPaise,
    this.initialCash,
    this.initialPreference,
  });

  final int orderAmountPaise;
  final double? initialCash;
  final String? initialPreference;

  @override
  State<CodSmartChangeDialog> createState() => _CodSmartChangeDialogState();
}

class _CodSmartChangeDialogState extends State<CodSmartChangeDialog> {
  late final TextEditingController _ctrl;
  String? _preference;

  double get _orderRupees => widget.orderAmountPaise / 100.0;

  double? get _cash {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  double? get _change {
    final c = _cash;
    if (c == null) return null;
    return c - _orderRupees;
  }

  bool get _insufficient => _cash != null && _cash! < _orderRupees;
  bool get _exact => _cash != null && (_cash! - _orderRupees).abs() < 0.0001;
  bool get _extra => _cash != null && _cash! > _orderRupees + 0.0001;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.initialCash == null ? '' : widget.initialCash!.toString(),
    );
    _preference = widget.initialPreference;
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _money(double v) => '₹${v.toStringAsFixed(2)}';

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'OXRO Smart Change',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _ckInk,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'How much cash are you going to pay?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _ckInk,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Order Amount: ${_money(_orderRupees)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('cod_cash_input'),
                controller: _ctrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Cash paying',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_cash != null)
                Text(
                  'Cash Paying: ${_money(_cash!)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              if (_change != null)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Text(
                    'Remaining Change: ${_money(_change!.abs())}',
                    key: ValueKey(_change),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              const SizedBox(height: 12),
              if (_insufficient) ...[
                Container(
                  key: const ValueKey('cod_change_insufficient'),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Text(
                    'Your cash amount is less than the order amount. '
                    'Required: ${_money(_orderRupees)}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              if (_exact) ...[
                Container(
                  key: const ValueKey('cod_change_exact'),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _ckTint,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _ckLine),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Perfect! You have the exact amount.',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Please pay ${_money(_orderRupees)} in cash to the delivery partner.',
                      ),
                      Text('Order Amount: ${_money(_orderRupees)}'),
                      Text('Cash Paying: ${_money(_cash!)}'),
                      Text('Remaining Change: ${_money(0)}'),
                      const Text('Status: No Change Required.'),
                    ],
                  ),
                ),
              ],
              if (_extra) ...[
                Text(
                  'What would you like to do with your ${_money(_change!)} change?',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                _optionTile(
                  key: const ValueKey('cod_change_option_wallet'),
                  label: 'Add ${_money(_change!)} to OXRO Wallet',
                  selected: _preference == 'wallet',
                  onTap: () => setState(() => _preference = 'wallet'),
                ),
                _optionTile(
                  key: const ValueKey('cod_change_option_physical'),
                  label: 'Receive ${_money(_change!)} physical cash',
                  selected: _preference == 'physical',
                  onTap: () => setState(() => _preference = 'physical'),
                ),
              ],
              const SizedBox(height: 12),
              if (_exact) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const ValueKey('cod_edit_amount'),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Edit Amount'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('cod_confirm_continue'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _ckAccent,
                        ),
                        onPressed: () => Navigator.of(context).pop(
                          CodSmartChangeResult(
                            cashAmount: _cash,
                            preference: null,
                            confirmed: true,
                          ),
                        ),
                        child: const Text('Confirm & Continue'),
                      ),
                    ),
                  ],
                ),
              ],
              if (_extra) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const ValueKey('cod_edit_amount'),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Edit Amount'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('cod_agree_continue'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _ckAccent,
                        ),
                        onPressed: _preference == null
                            ? null
                            : () => Navigator.of(context).pop(
                                CodSmartChangeResult(
                                  cashAmount: _cash,
                                  preference: _preference,
                                  confirmed: true,
                                ),
                              ),
                        child: const Text('Agree & Continue'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  key: const ValueKey('cod_no_thanks'),
                  onPressed: () => Navigator.of(context).pop(
                    CodSmartChangeResult(
                      cashAmount: _cash,
                      preference: null,
                      confirmed: true,
                    ),
                  ),
                  child: const Text('No Thanks'),
                ),
              ],
              if (!_cashValid) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const ValueKey('cod_edit_amount'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Edit Amount'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool get _cashValid => _cash != null && !_insufficient;

  Widget _optionTile({
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? _ckTint : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _ckAccent : _ckLine,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: _ckAccent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

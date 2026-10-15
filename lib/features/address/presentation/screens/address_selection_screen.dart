import 'package:flutter/material.dart';

import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/oxro_snack.dart';
import 'package:oxro/features/address/data/address_store.dart';
import 'package:oxro/features/address/presentation/widgets/address_sheet.dart';
import 'package:oxro/features/checkout/presentation/screens/checkout_screen.dart';

/// 14 Address Selection — ref 1:1: saved Home/Office cards + Edit,
/// + Add New Address, solid Continue → 15 Checkout.
/// Block + popup when continuing without a valid address.
class AddressSelectionScreen extends StatefulWidget {
  const AddressSelectionScreen({super.key, this.manageMode = false});

  /// When true, opened from Profile for managing (no Checkout CTA).
  final bool manageMode;

  @override
  State<AddressSelectionScreen> createState() =>
      _AddressSelectionScreenState();
}

class _AddressSelectionScreenState
    extends State<AddressSelectionScreen> {
  Future<void> _add() async {
    final ok = await AddressSheet.open(context);
    if (!mounted) return;
    if (ok) {
      showOxroSnack(context, 'Address saved');
      setState(() {});
    }
  }

  Future<void> _edit(Address a) async {
    final ok =
        await AddressSheet.open(context, existing: a);
    if (!mounted) return;
    if (ok) {
      showOxroSnack(context, 'Address updated');
      setState(() {});
    }
  }

  void _continue() {
    if (widget.manageMode) {
      Navigator.of(context).maybePop();
      return;
    }
    if (!AddressStore.instance.hasValid) {
      showOxroSnack(
          context, 'First fill your address');
      _add();
      return;
    }
    pushScreen(context, const CheckoutScreen());
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
                    child: Text(
                        widget.manageMode
                            ? 'My Addresses'
                            : 'Select Address',
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
                listenable: AddressStore.instance,
                builder: (context, _) {
                  final store = AddressStore.instance;
                  final items = store.items;
                  return ListView(
                    key: const ValueKey('addr_screen'),
                    padding: EdgeInsets.fromLTRB(
                        context.padX, 6, context.padX, 16),
                    children: [
                      for (var i = 0;
                          i < items.length;
                          i++)
                        _addrCard(
                            context, items[i], i),
                      GestureDetector(
                        key: const ValueKey('addr_add'),
                        onTap: _add,
                        behavior:
                            HitTestBehavior.opaque,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets
                              .symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(14),
                            border: Border.all(
                              color: OxroColors.primary,
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add,
                                  color:
                                      OxroColors.primary),
                              SizedBox(width: 6),
                              Text('Add New Address',
                                  style: TextStyle(
                                      fontWeight:
                                          FontWeight.w700,
                                      color: OxroColors
                                          .primary)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            if (!widget.manageMode)
              SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    context.padX, 8, context.padX, 14),
                child: GestureDetector(
                  key: const ValueKey('addr_continue'),
                  onTap: _continue,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: context.btnH,
                    constraints: const BoxConstraints(
                        minHeight: 48),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: OxroColors.primary,
                      borderRadius: BorderRadius.circular(
                          context.rs(12)),
                    ),
                    child: Text('Continue',
                        style: TextStyle(
                            fontSize: context.font(16),
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addrCard(
      BuildContext context, Address a, int i) {
    final store = AddressStore.instance;
    final sel = store.defaultId == a.id ||
        (store.defaultId == null && i == 0);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration:
          Duration(milliseconds: 250 + i * 60),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final t = v.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - t)),
            child: GestureDetector(
              key: ValueKey('addr_card_${a.id}'),
              onTap: () {
                if (!store.select(a.id) && context.mounted) {
                  showOxroSnack(context,
                      'Complete this address (Edit) before selecting');
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: EdgeInsets.only(
                    bottom: context.rs(10)),
                padding:
                    EdgeInsets.all(context.rs(12)),
                decoration: BoxDecoration(
                  color: sel
                      ? OxroColors.primary
                          .withValues(alpha: 0.05)
                      : Colors.white,
                  borderRadius:
                      BorderRadius.circular(14),
                  border: Border.all(
                    color: sel
                        ? OxroColors.primary
                        : OxroColors.border,
                    width: sel ? 1.8 : 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Icon(
                        sel
                            ? Icons
                                .radio_button_checked
                            : Icons.radio_button_off,
                        key: ValueKey(
                            'addr_radio_${a.id}'),
                        color: sel
                            ? OxroColors.primary
                            : OxroColors.muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                        horizontal: 8,
                                        vertical: 3),
                                decoration: BoxDecoration(
                                  color: OxroColors
                                      .royalBlue
                                      .withValues(
                                          alpha: 0.10),
                                  borderRadius:
                                      BorderRadius
                                          .circular(6),
                                ),
                                child: Text(a.label,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight:
                                            FontWeight
                                                .w800,
                                        color: OxroColors
                                            .royalBlue)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                    '${a.name} • ${a.phone}',
                                    maxLines: 1,
                                    overflow: TextOverflow
                                        .ellipsis,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight:
                                            FontWeight
                                                .w700)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                              '${a.line}, ${a.city} — ${a.pin}',
                              maxLines: 2,
                              overflow: TextOverflow
                                  .ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color:
                                      OxroColors.muted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      children: [
                        GestureDetector(
                          key: ValueKey(
                              'addr_edit_${a.id}'),
                          onTap: () => _edit(a),
                          behavior:
                              HitTestBehavior.opaque,
                          child: const Text('Edit',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight:
                                      FontWeight.w700,
                                  color: OxroColors
                                      .royalBlue)),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          key: ValueKey(
                              'addr_del_${a.id}'),
                          onTap: () =>
                              store.remove(a.id),
                          behavior:
                              HitTestBehavior.opaque,
                          child: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: OxroColors.muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/oxro_snack.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/wallet/data/wallet_store.dart';

const _creditGreen = Color(0xFF2E7D4F);

/// OXRO Wallet — balance + mock top-up + ledger.
/// All mock / in-memory; backend ledger replaces later.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with TickerProviderStateMixin {
  final _amtCtrl = TextEditingController();
  late final AnimationController _intro;
  late final AnimationController _ambient;
  bool? _reduceMotion;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion == reduce) return;
    _reduceMotion = reduce;
    if (reduce) {
      _intro.value = 1;
      _ambient.stop();
    } else {
      _intro.forward();
      _ambient.repeat();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _ambient.dispose();
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
      backgroundColor: OxroColors.premiumCream,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            const Positioned.fill(child: _WalletBackdrop()),
            Column(
              children: [
                _header(context),
                Expanded(
                  child: ListenableBuilder(
                    listenable: WalletStore.instance,
                    builder: (context, _) {
                      final store = WalletStore.instance;
                      final txs = store.txs;
                      return ListView(
                        key: const ValueKey('wallet_scroll'),
                        padding: EdgeInsets.fromLTRB(
                          context.padX,
                          context.rs(8),
                          context.padX,
                          context.rs(24),
                        ),
                        children: [
                          _Reveal(
                            controller: _intro,
                            start: 0,
                            end: 0.5,
                            dy: 16,
                            child: _balanceCard(context, store.balance),
                          ),
                          SizedBox(height: context.rs(14)),
                          _Reveal(
                            controller: _intro,
                            start: 0.18,
                            end: 0.5,
                            child: _quickAmounts(context),
                          ),
                          SizedBox(height: context.rs(10)),
                          _Reveal(
                            controller: _intro,
                            start: 0.24,
                            end: 0.58,
                            child: _customAmount(context),
                          ),
                          SizedBox(height: context.rs(18)),
                          _Reveal(
                            controller: _intro,
                            start: 0.3,
                            end: 0.6,
                            child: _sectionHeader(context, txs.length),
                          ),
                          SizedBox(height: context.rs(10)),
                          if (txs.isEmpty)
                            _Reveal(
                              controller: _intro,
                              start: 0.36,
                              end: 0.7,
                              child: _emptyState(context),
                            )
                          else
                            for (var i = 0; i < txs.length; i++)
                              _Reveal(
                                controller: _intro,
                                start: math.min(0.38 + i * 0.05, 0.8),
                                end: math.min(0.6 + i * 0.05, 1.0),
                                dy: 10,
                                child: _txTile(context, txs[i]),
                              ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return _Reveal(
      controller: _intro,
      start: 0,
      end: 0.35,
      dy: -6,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.rs(10),
          context.rs(8),
          context.padX,
          context.rs(6),
        ),
        child: Row(
          children: [
            _Pressable(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                width: context.rs(40),
                height: context.rs(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        OxroColors.premiumChampagne.withValues(alpha: 0.55),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: OxroColors.premiumDeep.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: context.rs(19),
                  color: OxroColors.premiumBurgundy,
                ),
              ),
            ),
            SizedBox(width: context.rs(10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OXRO Wallet',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: context.font(20),
                      fontWeight: FontWeight.w900,
                      color: OxroColors.premiumInk,
                      letterSpacing: 0.2,
                    ),
                  ),
                  SizedBox(height: context.rs(3)),
                  Row(
                    children: [
                      Container(
                        width: context.rs(18),
                        height: 1.2,
                        color: OxroColors.gold.withValues(alpha: 0.75),
                      ),
                      SizedBox(width: context.rs(5)),
                      Text(
                        'PREMIUM MONEY',
                        style: TextStyle(
                          fontSize: context.font(8.5),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: OxroColors.premiumMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: context.rs(8)),
            _ActivePill(
              controller: _ambient,
              reduce: _reduceMotion == true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _balanceCard(BuildContext context, int balance) {
    return AnimatedBuilder(
      animation: _ambient,
      builder: (context, child) {
        final reduce = _reduceMotion == true;
        final pulse = reduce
            ? 0.5
            : (math.sin(_ambient.value * math.pi * 2) + 1) / 2;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: OxroColors.premiumDeep.withValues(
                  alpha: 0.14 + 0.06 * pulse,
                ),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: OxroColors.premiumChampagne.withValues(
                  alpha: 0.08 + 0.10 * pulse,
                ),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            Container(
              key: const ValueKey('wallet_balance'),
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                context.rs(18),
                context.rs(16),
                context.rs(18),
                context.rs(14),
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    OxroColors.premiumDeep,
                    OxroColors.premiumBurgundy,
                    OxroColors.premiumWine,
                  ],
                ),
                border: Border.all(
                  color: OxroColors.premiumChampagne.withValues(alpha: 0.38),
                  width: 1.2,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -8,
                    top: -34,
                    child: Text(
                      'O',
                      style: TextStyle(
                        fontSize: context.rs(128),
                        height: 1,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withValues(alpha: 0.045),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: context.rs(38),
                            height: context.rs(38),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  OxroColors.premiumChampagne,
                                  OxroColors.goldSoft,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: OxroColors.premiumChampagne
                                      .withValues(alpha: 0.28),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.account_balance_wallet_rounded,
                              size: context.rs(19),
                              color: OxroColors.premiumBurgundy,
                            ),
                          ),
                          SizedBox(width: context.rs(10)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'OXRO Balance',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: context.font(11),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                    color: OxroColors.premiumChampagne,
                                  ),
                                ),
                                SizedBox(height: context.rs(2)),
                                Text(
                                  'Available to spend',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: context.font(9.5),
                                    color:
                                        Colors.white.withValues(alpha: 0.55),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: context.rs(8)),
                          const _DemoChip(),
                        ],
                      ),
                      SizedBox(height: context.rs(16)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: 0,
                            end: balance.toDouble(),
                          ),
                          duration: Duration(
                            milliseconds: _reduceMotion == true ? 0 : 650,
                          ),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) {
                            return Text(
                              Product.inr(value.round()),
                              style: TextStyle(
                                fontSize: context.font(34),
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: context.rs(3)),
                      Text(
                        'Use at checkout • No expiry in demo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: context.font(10.5),
                          color: Colors.white.withValues(alpha: 0.68),
                        ),
                      ),
                      SizedBox(height: context.rs(13)),
                      Container(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      SizedBox(height: context.rs(9)),
                      Row(
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            size: context.rs(14),
                            color: OxroColors.premiumChampagne,
                          ),
                          SizedBox(width: context.rs(4)),
                          Expanded(
                            child: Text(
                              'Instant top-up',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: context.font(10),
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.72),
                              ),
                            ),
                          ),
                          SizedBox(width: context.rs(8)),
                          Icon(
                            Icons.shield_outlined,
                            size: context.rs(13),
                            color: OxroColors.premiumChampagne
                                .withValues(alpha: 0.8),
                          ),
                          SizedBox(width: context.rs(4)),
                          Text(
                            'OXRO secured',
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: context.font(10),
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _ambient,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _WalletSheenPainter(
                        _ambient.value,
                        reduce: _reduceMotion == true,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAmounts(BuildContext context) {
    const amounts = [100, 500, 1000];
    return Row(
      children: [
        for (var i = 0; i < amounts.length; i++) ...[
          Expanded(
            child: _Pressable(
              key: ValueKey('wallet_add_${amounts[i]}'),
              onTap: () => _add(amounts[i]),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: context.rs(12)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color:
                        OxroColors.premiumChampagne.withValues(alpha: 0.8),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: OxroColors.premiumDeep.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: context.rs(15),
                      color: OxroColors.premiumBurgundy,
                    ),
                    SizedBox(width: context.rs(2)),
                    Text(
                      Product.inr(amounts[i]),
                      style: TextStyle(
                        fontSize: context.font(12.5),
                        fontWeight: FontWeight.w900,
                        color: OxroColors.premiumBurgundy,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (i != amounts.length - 1) SizedBox(width: context.rs(8)),
        ],
      ],
    );
  }

  Widget _customAmount(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            key: const ValueKey('wallet_amount'),
            controller: _amtCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addCustom(),
            style: TextStyle(
              fontSize: context.font(13),
              fontWeight: FontWeight.w600,
              color: OxroColors.premiumInk,
            ),
            decoration: InputDecoration(
              hintText: 'Custom amount (₹10–₹50,000)',
              hintStyle: TextStyle(
                color: OxroColors.premiumMuted.withValues(alpha: 0.75),
                fontSize: context.font(12),
              ),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: Icon(
                Icons.currency_rupee_rounded,
                size: context.rs(16),
                color: OxroColors.premiumBurgundy,
              ),
              prefixIconConstraints:
                  BoxConstraints(minWidth: context.rs(38)),
              contentPadding: EdgeInsets.symmetric(
                horizontal: context.rs(12),
                vertical: context.rs(13),
              ),
              border: _fieldBorder(),
              enabledBorder: _fieldBorder(),
              focusedBorder: _fieldBorder(focus: true),
            ),
          ),
        ),
        SizedBox(width: context.rs(10)),
        _Pressable(
          key: const ValueKey('wallet_add_custom'),
          onTap: _addCustom,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.rs(18),
              vertical: context.rs(14),
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  OxroColors.premiumBurgundy,
                  OxroColors.premiumWine,
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: OxroColors.premiumChampagne.withValues(alpha: 0.45),
              ),
              boxShadow: [
                BoxShadow(
                  color: OxroColors.premiumDeep.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_rounded,
                  size: context.rs(16),
                  color: OxroColors.premiumChampagne,
                ),
                SizedBox(width: context.rs(4)),
                Text(
                  'Add',
                  style: TextStyle(
                    fontSize: context.font(13),
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _fieldBorder({bool focus = false}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: focus
            ? OxroColors.premiumChampagne
            : OxroColors.premiumChampagne.withValues(alpha: 0.6),
        width: focus ? 1.4 : 1,
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, int count) {
    return Row(
      children: [
        Text(
          'Transactions',
          style: TextStyle(
            fontSize: context.font(15),
            fontWeight: FontWeight.w900,
            color: OxroColors.premiumInk,
          ),
        ),
        SizedBox(width: context.rs(10)),
        Expanded(
          child: Container(
            height: 1,
            color: OxroColors.premiumChampagne.withValues(alpha: 0.65),
          ),
        ),
        SizedBox(width: context.rs(8)),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.rs(8),
            vertical: context.rs(3),
          ),
          decoration: BoxDecoration(
            color: OxroColors.premiumBurgundy.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: context.font(10),
              fontWeight: FontWeight.w900,
              color: OxroColors.premiumBurgundy,
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyState(BuildContext context) {
    return Container(
      key: const ValueKey('wallet_empty'),
      padding: EdgeInsets.all(context.rs(16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: OxroColors.premiumChampagne.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: OxroColors.premiumDeep.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: context.rs(46),
            height: context.rs(46),
            decoration: BoxDecoration(
              color: OxroColors.premiumCreamDeep,
              shape: BoxShape.circle,
              border: Border.all(
                color: OxroColors.premiumChampagne.withValues(alpha: 0.7),
              ),
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: context.rs(21),
              color: OxroColors.premiumBurgundy,
            ),
          ),
          SizedBox(width: context.rs(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No transactions yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: context.font(13.5),
                    fontWeight: FontWeight.w800,
                    color: OxroColors.premiumInk,
                  ),
                ),
                SizedBox(height: context.rs(2)),
                Text(
                  'Top up to get started',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: context.font(11),
                    color: OxroColors.premiumMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _txTile(BuildContext context, WalletTx t) {
    final credit = t.amount >= 0;
    final accent = credit ? _creditGreen : OxroColors.premiumBurgundy;
    final date =
        '${t.date.day}/${t.date.month} • ${t.date.hour.toString().padLeft(2, '0')}:${t.date.minute.toString().padLeft(2, '0')}';
    return Container(
      key: ValueKey('wallet_tx_${t.id}'),
      margin: EdgeInsets.only(bottom: context.rs(9)),
      padding: EdgeInsets.all(context.rs(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: OxroColors.premiumChampagne.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: OxroColors.premiumDeep.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: context.rs(38),
            height: context.rs(38),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(color: accent.withValues(alpha: 0.25)),
            ),
            child: Icon(
              credit ? Icons.south_west_rounded : Icons.north_east_rounded,
              size: context.rs(18),
              color: accent,
            ),
          ),
          SizedBox(width: context.rs(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: context.font(13),
                    fontWeight: FontWeight.w700,
                    color: OxroColors.premiumInk,
                  ),
                ),
                SizedBox(height: context.rs(2)),
                Text(
                  date,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: context.font(10.5),
                    color: OxroColors.premiumMuted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: context.rs(8)),
          Text(
            '${credit ? '+' : '-'}${Product.inr(t.amount.abs())}',
            style: TextStyle(
              fontSize: context.font(13),
              fontWeight: FontWeight.w900,
              color: credit ? _creditGreen : OxroColors.premiumInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletBackdrop extends StatelessWidget {
  const _WalletBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [OxroColors.premiumCream, Colors.white],
              ),
            ),
          ),
        ),
        Positioned(
          top: -120,
          right: -80,
          width: 260,
          height: 260,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  OxroColors.premiumRose.withValues(alpha: 0.13),
                  OxroColors.premiumRose.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -140,
          left: -100,
          width: 280,
          height: 280,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  OxroColors.premiumChampagne.withValues(alpha: 0.18),
                  OxroColors.premiumChampagne.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.controller,
    required this.child,
    this.start = 0,
    this.end = 1,
    this.dy = 12,
  });

  final Animation<double> controller;
  final Widget child;
  final double start;
  final double end;
  final double dy;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final raw = ((controller.value - start) / (end - start))
            .clamp(0.0, 1.0)
            .toDouble();
        final v = Curves.easeOutCubic.transform(raw);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, dy * (1 - v)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _Pressable extends StatefulWidget {
  const _Pressable({super.key, required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _ActivePill extends StatelessWidget {
  const _ActivePill({required this.controller, required this.reduce});

  final Animation<double> controller;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.rs(10),
        vertical: context.rs(6),
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: OxroColors.premiumChampagne.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final t = reduce
                  ? 1.0
                  : (math.sin(controller.value * math.pi * 2) + 1) / 2;
              return Container(
                width: context.rs(6),
                height: context.rs(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: OxroColors.gold.withValues(alpha: 0.45 + 0.55 * t),
                  boxShadow: [
                    BoxShadow(
                      color: OxroColors.gold.withValues(alpha: 0.25 + 0.35 * t),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(width: context.rs(5)),
          Text(
            'ACTIVE',
            style: TextStyle(
              fontSize: context.font(8.5),
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              color: OxroColors.premiumBurgundy,
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoChip extends StatelessWidget {
  const _DemoChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.rs(8),
        vertical: context.rs(4),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: OxroColors.premiumChampagne.withValues(alpha: 0.4),
        ),
        color: Colors.white.withValues(alpha: 0.06),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: context.rs(5),
            height: context.rs(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: OxroColors.premiumChampagne.withValues(alpha: 0.9),
            ),
          ),
          SizedBox(width: context.rs(4)),
          Text(
            'DEMO',
            style: TextStyle(
              fontSize: context.font(8),
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletSheenPainter extends CustomPainter {
  const _WalletSheenPainter(this.t, {required this.reduce});

  final double t;
  final bool reduce;

  @override
  void paint(Canvas canvas, Size size) {
    if (reduce || size.width <= 0 || size.height <= 0) return;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-0.32);
    final left = (t * 2.4 - 1.7) * size.width;
    final rect = Rect.fromLTWH(
      left,
      -size.height,
      size.width * 0.42,
      size.height * 3,
    );
    final shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Colors.white.withValues(alpha: 0),
        Colors.white.withValues(alpha: 0.075),
        OxroColors.premiumChampagne.withValues(alpha: 0.07),
        Colors.white.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.42, 0.6, 1.0],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = shader);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WalletSheenPainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.reduce != reduce;
  }
}

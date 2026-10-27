import 'package:flutter/material.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/oxro_snack.dart';
import 'package:oxro/features/premium/data/premium_store.dart';

/// OXRO PREMIUM — burgundy + cream membership.
/// Mock subscription; backend billing replaces this later.
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  void _join() {
    PremiumStore.instance.join();
    showOxroSnack(context, 'Welcome to OXRO PREMIUM');
  }

  void _cancel() {
    PremiumStore.instance.cancel();
    showOxroSnack(context, 'PREMIUM membership cancelled');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PremiumStore.instance,
      builder: (context, _) {
        final member = PremiumStore.instance.isMember;
        return Scaffold(
          key: const ValueKey('premium_screen'),
          backgroundColor: OxroColors.pageBg,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    key: const ValueKey('premium_scroll'),
                    padding: EdgeInsets.zero,
                    children: [
                      _hero(context, member),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          context.padX,
                          20,
                          context.padX,
                          24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _benefits(context),
                            SizedBox(height: context.rs(16)),
                            _planCard(context),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _bottomBar(context, member),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _hero(BuildContext context, bool member) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            OxroColors.premiumDeep,
            OxroColors.premiumBurgundy,
            OxroColors.premiumWine,
          ],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      padding: EdgeInsets.fromLTRB(context.padX, 4, context.padX, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                key: const ValueKey('premium_back'),
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: OxroColors.premiumCream,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.24),
                  ),
                ),
                child: const Text(
                  'MEMBERSHIP',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: OxroColors.premiumCream,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _membershipCard(context, member),
            ),
          ),
        ],
      ),
    );
  }

  Widget _membershipCard(BuildContext context, bool member) {
    return Container(
      key: const ValueKey('premium_card'),
      padding: EdgeInsets.all(context.rs(18)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [OxroColors.premiumCream, OxroColors.premiumCreamDeep],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: OxroColors.premiumChampagne.withValues(alpha: 0.85),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: OxroColors.premiumBurgundy,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  size: 17,
                  color: OxroColors.premiumCream,
                ),
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'OXRO PREMIUM',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.3,
                    color: OxroColors.premiumBurgundy,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _statusPill(member ? 'ACTIVE' : '3 MONTHS ₹1'),
            ],
          ),
          const SizedBox(height: 18),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'FREE DELIVERY',
              maxLines: 1,
              style: TextStyle(
                fontSize: context.font(30),
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
                color: OxroColors.premiumBurgundy,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'on orders above ₹199',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: OxroColors.premiumMuted,
            ),
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 16),
            color: OxroColors.premiumChampagne.withValues(alpha: 0.7),
          ),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '3 months at ₹1',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: OxroColors.premiumInk,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                member ? 'PREMIUM ACTIVE' : 'Cancel anytime',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: member ? 0.8 : 0,
                  color: member
                      ? OxroColors.premiumBurgundy
                      : OxroColors.premiumMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: OxroColors.premiumBurgundy.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: OxroColors.premiumBurgundy.withValues(alpha: 0.15),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.7,
          color: OxroColors.premiumBurgundy,
        ),
      ),
    );
  }

  Widget _benefits(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        context.rs(16),
        context.rs(16),
        context.rs(16),
        context.rs(8),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OxroColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WHAT YOU GET',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.7,
              color: OxroColors.muted,
            ),
          ),
          const SizedBox(height: 10),
          _benefitRow(
            context,
            icon: Icons.delivery_dining_rounded,
            title: 'Free delivery',
            sub: 'On every order above ₹199',
          ),
          _benefitRow(
            context,
            icon: Icons.support_agent_rounded,
            title: 'Priority support',
            sub: 'Chat with our team first',
          ),
          _benefitRow(
            context,
            icon: Icons.local_offer_rounded,
            title: 'Member-only offers',
            sub: 'Early access to deals',
            last: true,
          ),
        ],
      ),
    );
  }

  Widget _benefitRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String sub,
    bool last = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 8 : 0),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: context.rs(9)),
            child: Row(
              children: [
                Container(
                  width: context.rs(38),
                  height: context.rs(38),
                  decoration: BoxDecoration(
                    color: OxroColors.premiumBurgundy.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: context.rs(19),
                    color: OxroColors.premiumBurgundy,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: OxroColors.charcoal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: OxroColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!last) const Divider(height: 1, color: OxroColors.border),
        ],
      ),
    );
  }

  Widget _planCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.rs(16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: OxroColors.premiumBurgundy.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: context.rs(32),
            height: context.rs(32),
            decoration: const BoxDecoration(
              color: OxroColors.premiumBurgundy,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 19,
              color: OxroColors.premiumCream,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '3 months at ₹1',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: OxroColors.charcoal,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Introductory offer • then ₹299/quarter',
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.25,
                    color: OxroColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '₹1',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: OxroColors.premiumBurgundy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(BuildContext context, bool member) {
    return Container(
      padding: EdgeInsets.fromLTRB(context.padX, 12, context.padX, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: OxroColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: member
            ? Column(
                key: const ValueKey('premium_manage'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: OxroColors.premiumCream,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: OxroColors.premiumBurgundy.withValues(
                          alpha: 0.25,
                        ),
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.workspace_premium_rounded,
                              size: 19,
                              color: OxroColors.premiumBurgundy,
                            ),
                            SizedBox(width: 7),
                            Text(
                              "You're a PREMIUM member",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: OxroColors.premiumBurgundy,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('premium_cancel'),
                    onPressed: _cancel,
                    child: const Text(
                      'Cancel membership',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: OxroColors.muted,
                      ),
                    ),
                  ),
                ],
              )
            : GestureDetector(
                key: const ValueKey('premium_join'),
                onTap: _join,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        OxroColors.premiumBurgundy,
                        OxroColors.premiumWine,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: OxroColors.premiumBurgundy.withValues(
                          alpha: 0.26,
                        ),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Join PREMIUM at ₹1',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: OxroColors.premiumCream,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: OxroColors.premiumCream,
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

import 'package:flutter/material.dart';

import 'package:oxro_pricing/oxro_pricing.dart';

import 'package:oxro/app/repositories/smart_change_repo.dart';
import 'package:oxro/features/notifications/data/notification_store.dart';
import 'package:oxro/features/wallet/data/wallet_store.dart';

/// Result of a Smart Change credit application pass.
class CreditApplyResult {
  const CreditApplyResult({this.appliedCount = 0, this.error});

  final int appliedCount;

  /// Non-null when every fetch attempt failed (backend unreachable etc).
  /// Zero [appliedCount] with a null error simply means nothing pending.
  final String? error;

  bool get ok => error == null;
}

/// Applies server-credited Smart Change transactions to the local
/// OXRO Money ledger + notification feed.
///
/// Shared by the Wallet screen and app startup so a credit shows up
/// without the customer having to open the wallet manually. Safe to
/// call repeatedly:
///   - [WalletStore.addPaise] dedupes by txn id
///   - [NotifStore.add] dedupes by notification id
///   - the backend `credited` list only returns fully-credited txns
class SmartChangeWalletCredit {
  SmartChangeWalletCredit._();

  /// Fetches credits for every customer id this device may have used
  /// (logged-in ↔ guest transitions) and applies the new ones.
  static Future<CreditApplyResult> apply() async {
    // The server wallet already holds every collected Smart Change credit;
    // applying them again locally would double the balance.
    if (WalletStore.instance.serverBacked) {
      return const CreditApplyResult();
    }
    final ids = <String>{SmartChangeRepo.currentCustomerId, 'guest'};
    final credits = <String, SmartChangeCredit>{};
    String? lastError;
    for (final id in ids) {
      try {
        final list = await SmartChangeRepo.instance.credited(id);
        for (final c in list) {
          if (c.txnId.isEmpty || c.walletCreditPaise <= 0) continue;
          credits[c.txnId] = c;
        }
      } on SmartChangeException catch (e) {
        lastError = e.message;
      } catch (_) {
        lastError = 'Could not reach OXRO Smart Change.';
      }
    }
    if (credits.isEmpty) {
      return CreditApplyResult(error: lastError);
    }
    var applied = 0;
    for (final c in credits.values) {
      final ok = WalletStore.instance.addPaise(
        c.walletCreditPaise,
        label: 'Smart Change — ${c.orderId}',
        txnId: c.txnId,
      );
      if (!ok) continue;
      applied++;
      NotifStore.instance.add(
        id: 'sc_${c.txnId}',
        title: 'Smart Change credit',
        sub:
            '${Money.inr(c.walletCreditPaise)} has been successfully '
            'credited to your OXRO Wallet through Smart Change.',
        icon: Icons.account_balance_wallet_outlined,
        kind: NotifKind.order,
      );
    }
    // Everything already applied locally still counts as success.
    return CreditApplyResult(appliedCount: applied, error: lastError);
  }
}

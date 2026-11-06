'use strict';

const { nowIso } = require('../utils/ids');
const { getSupabase, dbError, ensureCustomer } = require('../db/helpers');

const wallets = new Map(); // in-memory fallback

function wallet(customerId) {
  let w = wallets.get(customerId);
  if (!w) {
    w = { balancePaise: 0, transactions: [] };
    wallets.set(customerId, w);
  }
  return w;
}

function view(w) {
  return {
    balancePaise: w.balancePaise,
    transactions: w.transactions.map((t) => ({ ...t })),
  };
}

function fromRow(r) {
  return {
    id: r.id,
    label: r.label,
    amountPaise: r.amount_paise,
    orderId: r.order_id,
    createdAt: r.created_at,
  };
}

async function get(customerId) {
  const sb = getSupabase();
  if (!sb) return view(wallet(customerId));
  await ensureCustomer(customerId);
  const [{ data: wRow, error: wErr }, { data: txs, error: tErr }] = await Promise.all([
    sb.from('wallets').select('balance_paise').eq('customer_id', customerId).maybeSingle(),
    sb
      .from('wallet_transactions')
      .select('*')
      .eq('customer_id', customerId)
      .order('created_at', { ascending: false }),
  ]);
  if (wErr) throw dbError(wErr, 'wallet.get');
  if (tErr) throw dbError(tErr, 'wallet.tx');
  return {
    balancePaise: wRow ? wRow.balance_paise : 0,
    transactions: (txs || []).map(fromRow),
  };
}

/**
 * Credits a server-computed amount. `txnId` is the idempotency key:
 * replaying the same transaction never credits twice.
 */
async function credit(customerId, amountPaise, { txnId, label, orderId } = {}) {
  if (!Number.isInteger(amountPaise) || amountPaise <= 0) {
    return { credited: false, error: 'amountPaise must be a positive integer' };
  }
  const sb = getSupabase();
  if (!sb) {
    const w = wallet(customerId);
    if (txnId && w.transactions.some((t) => t.id === txnId)) {
      return { credited: false, duplicate: true };
    }
    w.balancePaise += amountPaise;
    const transaction = {
      id: txnId || `WTX${Date.now()}`,
      label: label || 'Wallet credit',
      amountPaise,
      orderId: orderId || null,
      createdAt: nowIso(),
    };
    w.transactions.unshift(transaction);
    return { credited: true, transaction };
  }

  await ensureCustomer(customerId);
  await sb.from('wallets').upsert(
    { customer_id: customerId, balance_paise: 0 },
    { onConflict: 'customer_id', ignoreDuplicates: true },
  );
  if (txnId) {
    const { data: dup, error: dErr } = await sb
      .from('wallet_transactions')
      .select('id')
      .eq('customer_id', customerId)
      .eq('id', txnId)
      .maybeSingle();
    if (dErr) throw dbError(dErr, 'wallet.credit.dup');
    if (dup) return { credited: false, duplicate: true };
  }
  const id = txnId || `WTX${Date.now()}`;
  const { data: tx, error: tErr } = await sb
    .from('wallet_transactions')
    .insert({
      id,
      customer_id: customerId,
      label: label || 'Wallet credit',
      amount_paise: amountPaise,
      order_id: orderId || null,
    })
    .select('*')
    .single();
  if (tErr) throw dbError(tErr, 'wallet.credit');
  const { data: wRow, error: rErr } = await sb
    .from('wallets')
    .select('balance_paise')
    .eq('customer_id', customerId)
    .maybeSingle();
  if (rErr) throw dbError(rErr, 'wallet.credit.read');
  const nextBalance = (wRow ? wRow.balance_paise : 0) + amountPaise;
  const { data: row, error: bErr } = await sb
    .from('wallets')
    .update({ balance_paise: nextBalance, updated_at: nowIso() })
    .eq('customer_id', customerId)
    .select('balance_paise')
    .single();
  if (bErr) throw dbError(bErr, 'wallet.credit.balance');
  return {
    credited: true,
    transaction: fromRow(tx),
    balancePaise: row ? row.balance_paise : undefined,
  };
}

async function debit(customerId, amountPaise, { txnId, label, orderId } = {}) {
  if (!Number.isInteger(amountPaise) || amountPaise <= 0) {
    return { ok: false, error: 'amountPaise must be a positive integer', code: 400 };
  }
  const sb = getSupabase();
  if (!sb) {
    const w = wallet(customerId);
    if (txnId && w.transactions.some((t) => t.id === txnId)) {
      return { ok: true, duplicate: true };
    }
    if (w.balancePaise < amountPaise) {
      return {
        ok: false,
        error: 'Insufficient OXRO Money balance',
        code: 409,
        balancePaise: w.balancePaise,
      };
    }
    w.balancePaise -= amountPaise;
    const transaction = {
      id: txnId || `WTX${Date.now()}`,
      label: label || 'Order payment',
      amountPaise: -amountPaise,
      orderId: orderId || null,
      createdAt: nowIso(),
    };
    w.transactions.unshift(transaction);
    return { ok: true, transaction };
  }

  await ensureCustomer(customerId);
  await sb.from('wallets').upsert(
    { customer_id: customerId, balance_paise: 0 },
    { onConflict: 'customer_id', ignoreDuplicates: true },
  );
  if (txnId) {
    const { data: dup, error: dErr } = await sb
      .from('wallet_transactions')
      .select('id')
      .eq('customer_id', customerId)
      .eq('id', txnId)
      .maybeSingle();
    if (dErr) throw dbError(dErr, 'wallet.debit.dup');
    if (dup) return { ok: true, duplicate: true };
  }
  const { data: wRow, error: rErr } = await sb
    .from('wallets')
    .select('balance_paise')
    .eq('customer_id', customerId)
    .maybeSingle();
  if (rErr) throw dbError(rErr, 'wallet.debit.read');
  const balance = wRow ? wRow.balance_paise : 0;
  if (balance < amountPaise) {
    return {
      ok: false,
      error: 'Insufficient OXRO Money balance',
      code: 409,
      balancePaise: balance,
    };
  }
  const id = txnId || `WTX${Date.now()}`;
  const { data: tx, error: tErr } = await sb
    .from('wallet_transactions')
    .insert({
      id,
      customer_id: customerId,
      label: label || 'Order payment',
      amount_paise: -amountPaise,
      order_id: orderId || null,
    })
    .select('*')
    .single();
  if (tErr) throw dbError(tErr, 'wallet.debit');
  const { error: bErr } = await sb
    .from('wallets')
    .update({ balance_paise: balance - amountPaise, updated_at: nowIso() })
    .eq('customer_id', customerId)
    .eq('balance_paise', balance);
  if (bErr) throw dbError(bErr, 'wallet.debit.balance');
  return { ok: true, transaction: fromRow(tx) };
}

function resetForTests() {
  wallets.clear();
}

module.exports = { get, credit, debit, resetForTests };

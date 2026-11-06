'use strict';

/**
 * OXRO Smart Change — transaction store (Supabase-backed with the same
 * in-memory implementation as fallback for tests / unset credentials).
 *
 * Status machine:
 *   activated -> order_linked -> collected -> credited | credit_pending
 *   any pre-collection state may move to cancelled.
 */
const crypto = require('crypto');
const { getSupabase, dbError, ensureCustomer } = require('../db/helpers');

/** Test hook: when true, the next wallet credit attempt fails. */
let failNextCredit = false;

function setFailNextCredit(v) {
  failNextCredit = !!v;
}

const txns = new Map(); // txnId -> record (fallback)
const byIdempotencyKey = new Map(); // key -> txnId
const appliedOrderIds = new Map(); // orderId -> txnId

function nowIso() {
  return new Date().toISOString();
}

function newTxnId() {
  return 'SC' + crypto.randomBytes(8).toString('hex').toUpperCase();
}

function newWalletTxnId() {
  return 'WTX' + crypto.randomBytes(8).toString('hex').toUpperCase();
}

function publicView(r) {
  return {
    txnId: r.txnId,
    orderId: r.orderId,
    customerId: r.customerId,
    partnerId: r.partnerId,
    orderAmountPaise: r.orderAmountPaise,
    declaredCashPaise: r.declaredCashPaise,
    actualCashPaise: r.actualCashPaise,
    remainingChangePaise: r.remainingChangePaise,
    consentStatus: r.consentStatus,
    walletTransactionId: r.walletTransactionId,
    transactionStatus: r.transactionStatus,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
  };
}

function fromRow(r) {
  if (!r) return null;
  return {
    txnId: r.txn_id,
    orderId: r.order_id,
    customerId: r.customer_id,
    partnerId: r.partner_id,
    orderAmountPaise: r.order_amount_paise,
    declaredCashPaise: r.declared_cash_paise,
    actualCashPaise: r.actual_cash_paise,
    remainingChangePaise: r.remaining_change_paise,
    consentStatus: r.consent_status,
    walletTransactionId: r.wallet_transaction_id,
    transactionStatus: r.transaction_status,
    idempotencyKey: r.idempotency_key,
    createdAt: r.created_at,
    updatedAt: r.updated_at,
  };
}

function toRow(record) {
  return {
    txn_id: record.txnId,
    order_id: record.orderId,
    customer_id: record.customerId,
    partner_id: record.partnerId,
    order_amount_paise: record.orderAmountPaise,
    declared_cash_paise: record.declaredCashPaise,
    actual_cash_paise: record.actualCashPaise,
    remaining_change_paise: record.remainingChangePaise,
    consent_status: record.consentStatus,
    wallet_transaction_id: record.walletTransactionId,
    transaction_status: record.transactionStatus,
    idempotency_key: record.idempotencyKey,
    created_at: record.createdAt,
    updated_at: record.updatedAt,
  };
}

function validateActivate({ customerId, orderAmountPaise, cashAmountPaise, idempotencyKey }) {
  if (!customerId) return { error: 'customerId is required' };
  if (!Number.isInteger(orderAmountPaise) || orderAmountPaise <= 0) {
    return { error: 'orderAmountPaise must be a positive integer' };
  }
  if (!Number.isInteger(cashAmountPaise) || cashAmountPaise <= 0) {
    return { error: 'cashAmountPaise must be a positive integer' };
  }
  if (cashAmountPaise < orderAmountPaise) {
    return { error: 'Cash amount must be equal to or greater than the order amount' };
  }
  if (!idempotencyKey || typeof idempotencyKey !== 'string') {
    return { error: 'idempotencyKey is required' };
  }
  return null;
}

/**
 * Create an activation record after customer consent + cash amount entry.
 * Server computes the change; a duplicate idempotency key returns the
 * original record (never a second transaction).
 */
async function activate({ customerId, orderAmountPaise, cashAmountPaise, idempotencyKey }) {
  const invalid = validateActivate({ customerId, orderAmountPaise, cashAmountPaise, idempotencyKey });
  if (invalid) return invalid;

  const sb = getSupabase();
  if (!sb) {
    const existingId = byIdempotencyKey.get(idempotencyKey);
    if (existingId) {
      const existing = txns.get(existingId);
      if (
        existing.customerId !== customerId ||
        existing.orderAmountPaise !== orderAmountPaise ||
        existing.declaredCashPaise !== cashAmountPaise
      ) {
        return { error: 'Idempotency key reused with a different payload', conflict: true };
      }
      return { record: existing, duplicate: true };
    }
    const ts = nowIso();
    const record = {
      txnId: newTxnId(),
      orderId: null,
      customerId,
      partnerId: null,
      orderAmountPaise,
      declaredCashPaise: cashAmountPaise,
      actualCashPaise: null,
      remainingChangePaise: cashAmountPaise - orderAmountPaise, // server-side math
      consentStatus: 'granted',
      walletTransactionId: null,
      transactionStatus: 'activated',
      idempotencyKey,
      createdAt: ts,
      updatedAt: ts,
    };
    txns.set(record.txnId, record);
    byIdempotencyKey.set(idempotencyKey, record.txnId);
    return { record };
  }

  await ensureCustomer(customerId);
  const { data: existing, error: eErr } = await sb
    .from('smart_change_transactions')
    .select('*')
    .eq('idempotency_key', idempotencyKey)
    .maybeSingle();
  if (eErr) throw dbError(eErr, 'smartChange.activate.lookup');
  if (existing) {
    const prev = fromRow(existing);
    if (
      prev.customerId !== customerId ||
      prev.orderAmountPaise !== orderAmountPaise ||
      prev.declaredCashPaise !== cashAmountPaise
    ) {
      return { error: 'Idempotency key reused with a different payload', conflict: true };
    }
    return { record: prev, duplicate: true };
  }
  const ts = nowIso();
  const record = {
    txnId: newTxnId(),
    orderId: null,
    customerId,
    partnerId: null,
    orderAmountPaise,
    declaredCashPaise: cashAmountPaise,
    actualCashPaise: null,
    remainingChangePaise: cashAmountPaise - orderAmountPaise,
    consentStatus: 'granted',
    walletTransactionId: null,
    transactionStatus: 'activated',
    idempotencyKey,
    createdAt: ts,
    updatedAt: ts,
  };
  const { data, error } = await sb
    .from('smart_change_transactions')
    .insert(toRow(record))
    .select('*')
    .single();
  if (error) {
    if (error.code === '23505') {
      // Race: another request won the unique idempotency key.
      const { data: raced, error: rErr } = await sb
        .from('smart_change_transactions')
        .select('*')
        .eq('idempotency_key', idempotencyKey)
        .single();
      if (rErr) throw dbError(rErr, 'smartChange.activate.race');
      return { record: fromRow(raced), duplicate: true };
    }
    throw dbError(error, 'smartChange.activate');
  }
  return { record: fromRow(data) };
}

/** Link an activated record to the placed order id. Idempotent. */
async function linkOrder(txnId, orderId) {
  if (!orderId || typeof orderId !== 'string') {
    return { error: 'orderId is required', code: 400 };
  }
  const sb = getSupabase();
  if (!sb) {
    const r = txns.get(txnId);
    if (!r) return { error: 'Smart Change transaction not found', code: 404 };
    if (r.transactionStatus === 'cancelled') {
      return { error: 'Transaction was cancelled', code: 409 };
    }
    if (r.transactionStatus === 'order_linked' || r.transactionStatus === 'collected' ||
        r.transactionStatus === 'credited' || r.transactionStatus === 'credit_pending') {
      if (r.orderId === orderId) return { record: r, duplicate: true };
      return { error: 'Transaction already linked to a different order', code: 409 };
    }
    const clash = appliedOrderIds.get(orderId);
    if (clash && clash !== txnId) {
      return { error: 'Order already has a Smart Change transaction', code: 409 };
    }
    r.orderId = orderId;
    r.transactionStatus = 'order_linked';
    r.updatedAt = nowIso();
    appliedOrderIds.set(orderId, txnId);
    return { record: r };
  }

  const { data: r, error: rErr } = await sb
    .from('smart_change_transactions')
    .select('*')
    .eq('txn_id', txnId)
    .maybeSingle();
  if (rErr) throw dbError(rErr, 'smartChange.link.read');
  if (!r) return { error: 'Smart Change transaction not found', code: 404 };
  if (r.transaction_status === 'cancelled') {
    return { error: 'Transaction was cancelled', code: 409 };
  }
  if (['order_linked', 'collected', 'credited', 'credit_pending'].includes(r.transaction_status)) {
    if (r.order_id === orderId) return { record: fromRow(r), duplicate: true };
    return { error: 'Transaction already linked to a different order', code: 409 };
  }
  const { data: clash, error: cErr } = await sb
    .from('smart_change_transactions')
    .select('txn_id')
    .eq('order_id', orderId)
    .maybeSingle();
  if (cErr) throw dbError(cErr, 'smartChange.link.clash');
  if (clash && clash.txn_id !== txnId) {
    return { error: 'Order already has a Smart Change transaction', code: 409 };
  }
  const { data: updated, error: uErr } = await sb
    .from('smart_change_transactions')
    .update({
      order_id: orderId,
      transaction_status: 'order_linked',
      updated_at: nowIso(),
    })
    .eq('txn_id', txnId)
    .select('*')
    .single();
  if (uErr) throw dbError(uErr, 'smartChange.link.write');
  return { record: fromRow(updated) };
}

/**
 * Delivery partner collects the COD payment. All verification and the
 * wallet credit amount are computed here — the partner can never set or
 * increase the credit. Repeated calls are idempotent (no double credit).
 */
async function collect(txnId, { partnerId, actualCashPaise }) {
  if (!partnerId || typeof partnerId !== 'string') {
    return { error: 'partnerId is required', code: 400 };
  }
  const sb = getSupabase();
  if (!sb) {
    const r = txns.get(txnId);
    if (!r) return { error: 'Smart Change transaction not found', code: 404 };
    if (r.transactionStatus === 'credited' || r.transactionStatus === 'collected') {
      return { record: r, duplicate: true };
    }
    if (r.transactionStatus === 'cancelled') {
      return { error: 'Order/transaction cancelled — no wallet credit allowed', code: 409 };
    }
    if (r.transactionStatus !== 'order_linked' && r.transactionStatus !== 'credit_pending') {
      return { error: 'Order is not linked to this Smart Change transaction', code: 409 };
    }
    if (r.consentStatus !== 'granted') {
      return { error: 'Customer authorization missing', code: 403 };
    }
    if (!Number.isInteger(actualCashPaise) || actualCashPaise < r.orderAmountPaise) {
      return { error: 'Actual cash received must be >= order amount', code: 400 };
    }
    r.partnerId = partnerId;
    r.actualCashPaise = actualCashPaise;
    const changePaise = actualCashPaise - r.orderAmountPaise;
    r.remainingChangePaise = changePaise;
    r.transactionStatus = 'collected';
    r.updatedAt = nowIso();
    if (failNextCredit) {
      failNextCredit = false;
      r.transactionStatus = 'credit_pending';
      r.updatedAt = nowIso();
      return { record: r, creditFailed: true };
    }
    r.walletTransactionId = newWalletTxnId();
    r.transactionStatus = 'credited';
    r.updatedAt = nowIso();
    return { record: r };
  }

  const { data: r, error: rErr } = await sb
    .from('smart_change_transactions')
    .select('*')
    .eq('txn_id', txnId)
    .maybeSingle();
  if (rErr) throw dbError(rErr, 'smartChange.collect.read');
  if (!r) return { error: 'Smart Change transaction not found', code: 404 };
  if (r.transaction_status === 'credited' || r.transaction_status === 'collected') {
    return { record: fromRow(r), duplicate: true };
  }
  if (r.transaction_status === 'cancelled') {
    return { error: 'Order/transaction cancelled — no wallet credit allowed', code: 409 };
  }
  if (r.transaction_status !== 'order_linked' && r.transaction_status !== 'credit_pending') {
    return { error: 'Order is not linked to this Smart Change transaction', code: 409 };
  }
  if (r.consent_status !== 'granted') {
    return { error: 'Customer authorization missing', code: 403 };
  }
  if (!Number.isInteger(actualCashPaise) || actualCashPaise < r.order_amount_paise) {
    return { error: 'Actual cash received must be >= order amount', code: 400 };
  }

  const changePaise = actualCashPaise - r.order_amount_paise;
  if (failNextCredit) {
    failNextCredit = false;
    const { data, error } = await sb
      .from('smart_change_transactions')
      .update({
        partner_id: partnerId,
        actual_cash_paise: actualCashPaise,
        remaining_change_paise: changePaise,
        transaction_status: 'credit_pending',
        updated_at: nowIso(),
      })
      .eq('txn_id', txnId)
      .select('*')
      .single();
    if (error) throw dbError(error, 'smartChange.collect.pending');
    return { record: fromRow(data), creditFailed: true };
  }

  const { data, error } = await sb
    .from('smart_change_transactions')
    .update({
      partner_id: partnerId,
      actual_cash_paise: actualCashPaise,
      remaining_change_paise: changePaise,
      transaction_status: 'credited',
      wallet_transaction_id: newWalletTxnId(),
      updated_at: nowIso(),
    })
    .eq('txn_id', txnId)
    .select('*')
    .single();
  if (error) throw dbError(error, 'smartChange.collect');
  return { record: fromRow(data) };
}

async function cancel(txnId) {
  const sb = getSupabase();
  if (!sb) {
    const r = txns.get(txnId);
    if (!r) return { error: 'Smart Change transaction not found', code: 404 };
    if (r.transactionStatus === 'credited' || r.transactionStatus === 'collected') {
      return { error: 'Cannot cancel after collection', code: 409 };
    }
    if (r.transactionStatus === 'cancelled') return { record: r, duplicate: true };
    r.transactionStatus = 'cancelled';
    r.updatedAt = nowIso();
    return { record: r };
  }
  const { data: r, error: rErr } = await sb
    .from('smart_change_transactions')
    .select('*')
    .eq('txn_id', txnId)
    .maybeSingle();
  if (rErr) throw dbError(rErr, 'smartChange.cancel.read');
  if (!r) return { error: 'Smart Change transaction not found', code: 404 };
  if (r.transaction_status === 'credited' || r.transaction_status === 'collected') {
    return { error: 'Cannot cancel after collection', code: 409 };
  }
  if (r.transaction_status === 'cancelled') return { record: fromRow(r), duplicate: true };
  const { data, error } = await sb
    .from('smart_change_transactions')
    .update({ transaction_status: 'cancelled', updated_at: nowIso() })
    .eq('txn_id', txnId)
    .select('*')
    .single();
  if (error) throw dbError(error, 'smartChange.cancel');
  return { record: fromRow(data) };
}

async function get(txnId) {
  const sb = getSupabase();
  if (!sb) return txns.get(txnId) || null;
  const { data, error } = await sb
    .from('smart_change_transactions')
    .select('*')
    .eq('txn_id', txnId)
    .maybeSingle();
  if (error) throw dbError(error, 'smartChange.get');
  return fromRow(data);
}

/** Credited transactions awaiting client-side wallet application. */
async function creditedForCustomer(customerId) {
  const sb = getSupabase();
  if (!sb) {
    return [...txns.values()].filter(
      (r) => r.customerId === customerId && r.transactionStatus === 'credited',
    );
  }
  const { data, error } = await sb
    .from('smart_change_transactions')
    .select('*')
    .eq('customer_id', customerId)
    .eq('transaction_status', 'credited');
  if (error) throw dbError(error, 'smartChange.credited');
  return (data || []).map(fromRow);
}

/** Orders a delivery partner can still collect (linked or retryable). */
async function collectable() {
  const sb = getSupabase();
  if (!sb) {
    return [...txns.values()].filter(
      (r) => r.transactionStatus === 'order_linked' || r.transactionStatus === 'credit_pending',
    );
  }
  const { data, error } = await sb
    .from('smart_change_transactions')
    .select('*')
    .in('transaction_status', ['order_linked', 'credit_pending']);
  if (error) throw dbError(error, 'smartChange.collectable');
  return (data || []).map(fromRow);
}

function resetForTests() {
  txns.clear();
  byIdempotencyKey.clear();
  appliedOrderIds.clear();
  failNextCredit = false;
}

module.exports = {
  activate,
  linkOrder,
  collect,
  cancel,
  get,
  creditedForCustomer,
  collectable,
  setFailNextCredit,
  resetForTests,
  publicView,
};

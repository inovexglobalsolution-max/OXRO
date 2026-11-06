'use strict';

const store = require('../services/smartChangeStore');
const walletStore = require('../services/walletStore');

/**
 * Mirror a successful Smart Change credit into the server wallet ledger.
 * `walletTransactionId` is the idempotency key, so retries never
 * double-credit.
 */
async function mirrorWalletCredit(record) {
  if (!record || !record.walletTransactionId) return;
  await walletStore.credit(record.customerId, record.remainingChangePaise, {
    txnId: record.walletTransactionId,
    label: `Smart Change — ${record.orderId || 'COD'}`,
    orderId: record.orderId,
  });
}

const smartChangeController = {
  activate: async (req, res) => {
    const { customerId, orderAmountPaise, cashAmountPaise, idempotencyKey } = req.body || {};
    const out = await store.activate({
      customerId,
      orderAmountPaise: Number(orderAmountPaise),
      cashAmountPaise: Number(cashAmountPaise),
      idempotencyKey,
    });
    if (out.error) {
      return res.status(out.conflict ? 409 : 400).json({ error: out.error });
    }
    return res.status(out.duplicate ? 200 : 201).json({
      ...store.publicView(out.record),
      duplicate: !!out.duplicate,
      remainingChangePaise: out.record.remainingChangePaise,
    });
  },

  linkOrder: async (req, res) => {
    const { orderId } = req.body || {};
    const out = await store.linkOrder(req.params.txnId, orderId);
    if (out.error) return res.status(out.code || 400).json({ error: out.error });
    return res.json({ ...store.publicView(out.record), duplicate: !!out.duplicate });
  },

  collect: async (req, res) => {
    const { partnerId, actualCashPaise } = req.body || {};
    const out = await store.collect(req.params.txnId, {
      partnerId,
      actualCashPaise: Number(actualCashPaise),
    });
    if (out.error) return res.status(out.code || 400).json({ error: out.error });
    if (out.creditFailed) {
      return res.status(502).json({
        ...store.publicView(out.record),
        error: 'Wallet credit failed — transaction pending reconciliation',
      });
    }
    await mirrorWalletCredit(out.record);
    return res.json({
      ...store.publicView(out.record),
      duplicate: !!out.duplicate,
      remainingChangePaise: out.record.remainingChangePaise,
    });
  },

  cancel: async (req, res) => {
    const out = await store.cancel(req.params.txnId);
    if (out.error) return res.status(out.code || 400).json({ error: out.error });
    return res.json(store.publicView(out.record));
  },

  getById: async (req, res) => {
    const r = await store.get(req.params.txnId);
    if (!r) return res.status(404).json({ error: 'Smart Change transaction not found' });
    return res.json(store.publicView(r));
  },

  credited: async (req, res) => {
    const customerId = req.query.customerId;
    if (!customerId) return res.status(400).json({ error: 'customerId is required' });
    const list = await store.creditedForCustomer(String(customerId));
    return res.json({
      transactions: list.map(store.publicView),
    });
  },

  collectable: async (req, res) => {
    const list = await store.collectable();
    return res.json({
      transactions: list.map(store.publicView),
    });
  },
};

module.exports = smartChangeController;

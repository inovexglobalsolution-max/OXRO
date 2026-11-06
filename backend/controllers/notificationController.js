'use strict';

const store = require('../services/notificationStore');
const { customerIdFrom } = require('../utils/request');

const notificationController = {
  list: async (req, res) => {
    res.json({ notifications: await store.list(customerIdFrom(req)) });
  },

  create: async (req, res) => {
    const out = await store.create(customerIdFrom(req), req.body || {});
    if (out.error) return res.status(out.code || 400).json({ error: out.error });
    res.status(201).json({ notification: out.notification });
  },

  markRead: async (req, res) => {
    const unread = req.body ? req.body.unread : undefined;
    const out = await store.markRead(
      customerIdFrom(req),
      req.params.id,
      unread === undefined ? false : !!unread,
    );
    if (out.error) return res.status(out.code || 400).json({ error: out.error });
    res.json(out);
  },

  markAllRead: async (req, res) => {
    res.json(await store.markAllRead(customerIdFrom(req)));
  },
};

module.exports = notificationController;

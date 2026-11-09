'use strict';

const { safeId, nowIso } = require('../utils/ids');
const { getSupabase, dbError, ensureCustomer } = require('../db/helpers');

const partners = new Map(); // in-memory fallback only
const locations = new Map(); // partner_id -> {latitude, longitude, accuracy, updated_at}
const assignments = new Map(); // order_id -> {partner_id, assigned_at, picked_up_at, delivered_at}

function rowToPartner(r) {
  if (!r) return null;
  return {
    id: r.id,
    name: r.name,
    phone: r.phone,
    photoUrl: r.photo_url,
    rating: r.rating == null ? null : Number(r.rating),
    completedDeliveries: r.completed_deliveries ?? 0,
    vehicleType: r.vehicle_type,
    vehicleNumber: r.vehicle_number,
    verified: r.verified !== false,
  };
}

function rowToLocation(r) {
  if (!r) return null;
  return {
    latitude: r.latitude,
    longitude: r.longitude,
    accuracy: r.accuracy_m,
    updatedAt: r.updated_at,
  };
}

function rowToAssignment(r) {
  if (!r) return null;
  return {
    partnerId: r.partner_id,
    assignedAt: r.assigned_at,
    pickedUpAt: r.picked_up_at,
    deliveredAt: r.delivered_at,
  };
}

async function getPartner(id) {
  const sb = getSupabase();
  if (!sb) {
    return partners.get(id) || null;
  }
  const { data, error } = await sb
    .from('delivery_partners')
    .select('*')
    .eq('id', id)
    .maybeSingle();
  if (error) throw dbError(error, 'deliveryPartner.get');
  return rowToPartner(data);
}

async function listPartners() {
  const sb = getSupabase();
  if (!sb) {
    return [...partners.values()];
  }
  const { data, error } = await sb
    .from('delivery_partners')
    .select('*')
    .eq('verified', true)
    .order('completed_deliveries', { ascending: false });
  if (error) throw dbError(error, 'deliveryPartner.list');
  return (data || []).map(rowToPartner);
}

async function getLocation(partnerId) {
  const sb = getSupabase();
  if (!sb) {
    return locations.get(partnerId) || null;
  }
  const { data, error } = await sb
    .from('delivery_partner_locations')
    .select('*')
    .eq('partner_id', partnerId)
    .maybeSingle();
  if (error) throw dbError(error, 'deliveryPartner.location.get');
  return rowToLocation(data);
}

async function upsertLocation(partnerId, { latitude, longitude, accuracy } = {}) {
  const lat = Number(latitude);
  const lng = Number(longitude);
  if (!Number.isFinite(lat) || lat < -90 || lat > 90) {
    return { error: 'latitude must be between -90 and 90', code: 400 };
  }
  if (!Number.isFinite(lng) || lng < -180 || lng > 180) {
    return { error: 'longitude must be between -180 and 180', code: 400 };
  }
  const sb = getSupabase();
  const now = nowIso();
  if (!sb) {
    const loc = {
      latitude: lat,
      longitude: lng,
      accuracy: Number.isFinite(Number(accuracy)) ? Number(accuracy) : null,
      updatedAt: now,
    };
    locations.set(partnerId, loc);
    return { location: loc };
  }
  const { data: partner, error: pErr } = await sb
    .from('delivery_partners')
    .select('id')
    .eq('id', partnerId)
    .maybeSingle();
  if (pErr) throw dbError(pErr, 'deliveryPartner.location.partner');
  if (!partner) return { error: 'Delivery partner not found', code: 404 };
  const { data, error } = await sb
    .from('delivery_partner_locations')
    .upsert(
      {
        partner_id: partnerId,
        latitude: lat,
        longitude: lng,
        accuracy_m: Number.isFinite(Number(accuracy)) ? Number(accuracy) : null,
        updated_at: now,
      },
      { onConflict: 'partner_id' },
    )
    .select('*')
    .single();
  if (error) throw dbError(error, 'deliveryPartner.location.upsert');
  return { location: rowToLocation(data) };
}

async function getAssignment(orderId) {
  const sb = getSupabase();
  if (!sb) {
    return assignments.get(orderId) || null;
  }
  const { data, error } = await sb
    .from('order_delivery_assignments')
    .select('*')
    .eq('order_id', orderId)
    .maybeSingle();
  if (error) throw dbError(error, 'deliveryPartner.assignment.get');
  return rowToAssignment(data);
}

async function assignOrder(orderId, partnerId) {
  const sb = getSupabase();
  const now = nowIso();
  if (!sb) {
    if (!partners.has(partnerId) && partnerId !== 'DP001') {
      return { error: 'Delivery partner not found', code: 404 };
    }
    const assignment = {
      partnerId,
      assignedAt: now,
      pickedUpAt: null,
      deliveredAt: null,
    };
    assignments.set(orderId, assignment);
    return { assignment };
  }
  const partner = await getPartner(partnerId);
  if (!partner) return { error: 'Delivery partner not found', code: 404 };
  const { data, error } = await sb
    .from('order_delivery_assignments')
    .upsert(
      { order_id: orderId, partner_id: partnerId, assigned_at: now },
      { onConflict: 'order_id' },
    )
    .select('*')
    .single();
  if (error) throw dbError(error, 'deliveryPartner.assignment.upsert');
  await sb
    .from('orders')
    .update({ delivery_partner_id: partnerId, updated_at: now })
    .eq('id', orderId);
  return { assignment: rowToAssignment(data) };
}

async function markPickedUp(orderId) {
  return markStep(orderId, 'picked_up_at');
}

async function markDelivered(orderId) {
  return markStep(orderId, 'delivered_at');
}

async function markStep(orderId, column) {
  const sb = getSupabase();
  const now = nowIso();
  if (!sb) {
    const a = assignments.get(orderId);
    if (!a) return { error: 'Order is not assigned yet', code: 409 };
    const next = { ...a, [column]: now };
    assignments.set(orderId, next);
    return { assignment: next };
  }
  const { data, error } = await sb
    .from('order_delivery_assignments')
    .update({ [column]: now, updated_at: now })
    .eq('order_id', orderId)
    .select('*')
    .maybeSingle();
  if (error) throw dbError(error, 'deliveryPartner.assignment.step');
  if (!data) return { error: 'Order is not assigned yet', code: 409 };
  return { assignment: rowToAssignment(data) };
}

async function tracking(orderId) {
  const sb = getSupabase();
  if (!sb) {
    const assignment = assignments.get(orderId) || null;
    const partner = assignment ? await getPartner(assignment.partnerId) : null;
    const location = partner ? await getLocation(partner.id) : null;
    return { assignment, partner, location };
  }
  const assignment = await getAssignment(orderId);
  const partner = assignment ? await getPartner(assignment.partnerId) : null;
  const location = partner ? await getLocation(partner.id) : null;
  return { assignment, partner, location };
}

function seedPartnerForTests(partner) {
  partners.set(partner.id, {
    id: partner.id,
    name: partner.name || 'Test Partner',
    phone: partner.phone || '9876543210',
    photoUrl: partner.photoUrl || null,
    rating: partner.rating == null ? 4.5 : Number(partner.rating),
    completedDeliveries: partner.completedDeliveries ?? 10,
    vehicleType: partner.vehicleType || 'Motorcycle',
    vehicleNumber: partner.vehicleNumber || 'TN 09 AB 1234',
    verified: partner.verified !== false,
  });
}

function resetForTests() {
  partners.clear();
  locations.clear();
  assignments.clear();
}

module.exports = {
  getPartner,
  listPartners,
  getLocation,
  upsertLocation,
  getAssignment,
  assignOrder,
  markPickedUp,
  markDelivered,
  tracking,
  resetForTests,
  seedPartnerForTests,
};

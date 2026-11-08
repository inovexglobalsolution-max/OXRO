'use strict';

const { nowIso, safeId } = require('../utils/ids');
const { getSupabase, dbError, ensureCustomer } = require('../db/helpers');

const bookings = new Map(); // customerId -> [booking] (fallback)

function fromRow(r) {
  return {
    id: r.id,
    restaurantId: r.restaurant_id,
    customerName: r.customer_name || null,
    customerPhone: r.customer_phone || null,
    guests: r.guests,
    slot: r.slot,
    bookingDate: r.booking_date || null,
    bookingTime: r.booking_time || null,
    bookingStatus: r.booking_status || 'confirmed',
    specialRequest: r.special_request || r.note || null,
    note: r.note,
    createdAt: r.created_at,
    updatedAt: r.updated_at || null,
  };
}

async function list(customerId) {
  const sb = getSupabase();
  if (!sb) return bookings.get(customerId) || [];
  await ensureCustomer(customerId);
  const { data, error } = await sb
    .from('dineout_bookings')
    .select('*')
    .eq('customer_id', customerId)
    .order('created_at', { ascending: false });
  if (error) throw dbError(error, 'dineout.list');
  return (data || []).map(fromRow);
}

async function create(customerId, data = {}) {
  const restaurantId = String(data.restaurantId || '').trim();
  if (!restaurantId) return { error: 'restaurantId is required', code: 400 };
  const guests = Number(data.guests);
  if (!Number.isInteger(guests) || guests <= 0) {
    return { error: 'guests must be a positive integer', code: 400 };
  }
  const slot = String(data.slot || '').trim();
  if (!slot) return { error: 'slot is required', code: 400 };
  const record = {
    id: safeId(data.id, 'bkg'),
    restaurantId,
    customerName: String(data.customerName || data.customer_name || '').trim() || null,
    customerPhone: String(data.customerPhone || data.customer_phone || '').trim() || null,
    guests,
    slot,
    bookingDate: data.bookingDate || data.booking_date || null,
    bookingTime: data.bookingTime || data.booking_time || null,
    bookingStatus: String(data.bookingStatus || data.booking_status || 'confirmed').trim(),
    specialRequest: String(data.specialRequest || data.special_request || data.note || '').slice(0, 300) || null,
    note: String(data.note || '').slice(0, 300) || null,
    createdAt: nowIso(),
  };

  const sb = getSupabase();
  if (!sb) {
    const list0 = bookings.get(customerId) || [];
    list0.unshift(record);
    bookings.set(customerId, list0);
    return { booking: record };
  }
  await ensureCustomer(customerId);
  const { data: row, error } = await sb
    .from('dineout_bookings')
    .insert({
      id: record.id,
      customer_id: customerId,
      restaurant_id: record.restaurantId,
      customer_name: record.customerName,
      customer_phone: record.customerPhone,
      guests: record.guests,
      slot: record.slot,
      booking_date: record.bookingDate,
      booking_time: record.bookingTime,
      booking_status: record.bookingStatus,
      special_request: record.specialRequest,
      note: record.note,
    })
    .select('*')
    .single();
  if (error) throw dbError(error, 'dineout.create');
  return { booking: fromRow(row) };
}

function resetForTests() {
  bookings.clear();
}

module.exports = { list, create, resetForTests };

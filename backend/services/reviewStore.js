'use strict';

const { nowIso } = require('../utils/ids');
const { getSupabase, dbError, ensureCustomer } = require('../db/helpers');

const mine = new Map(); // customerId -> Map<productId, review> (fallback)

function fromRow(r) {
  return {
    productId: r.product_id,
    rating: r.rating,
    body: r.body,
    photos: r.photos || [],
    hasVideo: r.has_video,
    createdAt: r.created_at,
  };
}

async function list(customerId) {
  const sb = getSupabase();
  if (!sb) {
    const m = mine.get(customerId);
    return m ? [...m.values()] : [];
  }
  await ensureCustomer(customerId);
  const { data, error } = await sb
    .from('reviews')
    .select('product_id, rating, body, photos, has_video, created_at')
    .eq('customer_id', customerId)
    .order('created_at', { ascending: false });
  if (error) throw dbError(error, 'reviews.list');
  return (data || []).map(fromRow);
}

async function upsert(customerId, data = {}) {
  const productId = Number(data.productId);
  const rating = Number(data.rating);
  if (!Number.isInteger(productId) || productId <= 0) {
    return { error: 'productId must be a positive integer', code: 400 };
  }
  if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
    return { error: 'rating must be an integer between 1 and 5', code: 400 };
  }
  const body = String(data.body || '').slice(0, 1000);
  const photos = Array.isArray(data.photos) ? data.photos : [];
  const hasVideo = !!data.hasVideo;

  const sb = getSupabase();
  if (!sb) {
    let m = mine.get(customerId);
    if (!m) {
      m = new Map();
      mine.set(customerId, m);
    }
    const review = { productId, rating, body, photos, hasVideo, createdAt: nowIso() };
    m.set(productId, review);
    return { review };
  }
  await ensureCustomer(customerId);
  const { data: row, error } = await sb
    .from('reviews')
    .upsert(
      {
        id: `rev_${customerId}_${productId}`,
        customer_id: customerId,
        product_id: productId,
        rating,
        body,
        photos,
        has_video: hasVideo,
        updated_at: nowIso(),
      },
      { onConflict: 'customer_id,product_id' },
    )
    .select('product_id, rating, body, photos, has_video, created_at')
    .single();
  if (error) throw dbError(error, 'reviews.upsert');
  return { review: fromRow(row) };
}

function resetForTests() {
  mine.clear();
}

module.exports = { list, upsert, resetForTests };

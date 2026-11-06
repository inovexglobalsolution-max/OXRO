'use strict';

/**
 * Seeded catalogue. With Supabase configured the rows live in the
 * `restaurants`/`dishes` tables (same data); the hardcoded copy below is
 * the fallback used by tests and while credentials are unset.
 */
const { getSupabase, dbError } = require('../db/helpers');

const _c = [0xffffffff, 0xffff6a00];
const _g = [0xffffffff, 0xff2e7d4f];

function dish(id, name, brand, restaurantId, restaurantName, price, mrp, opts = {}) {
  return {
    id,
    name,
    brand,
    price,
    mrp,
    rating: opts.rating ?? 4.3,
    reviews: opts.reviews ?? 120,
    icon: opts.icon ?? 0xe56c,
    colors: opts.colors ?? _c,
    restaurantId,
    restaurantName,
    veg: !!opts.veg,
    egg: !!opts.egg,
    description: opts.description ?? '',
    imageUrl: null,
  };
}

const restaurants = [
  {
    id: 'r_paradise',
    name: 'Paradise Biryani',
    cuisines: ['Biryani', 'Hyderabadi'],
    rating: 4.5,
    reviews: 3200,
    distanceLabel: '2.1 km',
    etaMinutes: 30,
    menu: [
      dish(900001, 'Hyderabadi Chicken Biryani', 'Paradise Biryani', 'r_paradise', 'Paradise Biryani', 249, 299, { reviews: 980 }),
      dish(900002, 'Mutton Dum Biryani', 'Paradise Biryani', 'r_paradise', 'Paradise Biryani', 329, 399, { reviews: 640 }),
      dish(900003, 'Veg Dum Biryani', 'Paradise Biryani', 'r_paradise', 'Paradise Biryani', 199, 249, { veg: true, reviews: 410 }),
    ],
  },
  {
    id: 'r_saravana',
    name: 'Saravana Bhavan',
    cuisines: ['South Indian', 'Vegetarian'],
    rating: 4.4,
    reviews: 5100,
    distanceLabel: '1.4 km',
    etaMinutes: 25,
    menu: [
      dish(900011, 'Ghee Roast Dosa', 'Saravana Bhavan', 'r_saravana', 'Saravana Bhavan', 89, 110, { veg: true, colors: _g, reviews: 1500 }),
      dish(900012, 'Masala Dosa', 'Saravana Bhavan', 'r_saravana', 'Saravana Bhavan', 79, 99, { veg: true, colors: _g, reviews: 1320 }),
      dish(900013, 'Idli Vada Combo', 'Saravana Bhavan', 'r_saravana', 'Saravana Bhavan', 69, 85, { veg: true, colors: _g, reviews: 890 }),
    ],
  },
  {
    id: 'r_dominos',
    name: "Domino's Pizza",
    cuisines: ['Pizza', 'Fast Food'],
    rating: 4.2,
    reviews: 8400,
    distanceLabel: '3.2 km',
    etaMinutes: 35,
    menu: [
      dish(900021, 'Margherita Pizza', "Domino's Pizza", 'r_dominos', "Domino's Pizza", 219, 269, { veg: true, reviews: 2100 }),
      dish(900022, 'Peppy Paneer Pizza', "Domino's Pizza", 'r_dominos', "Domino's Pizza", 299, 359, { veg: true, reviews: 1200 }),
      dish(900023, 'Chicken Dominator Pizza', "Domino's Pizza", 'r_dominos', "Domino's Pizza", 399, 469, { reviews: 980 }),
    ],
  },
  {
    id: 'r_bbq',
    name: 'BBQ Nation',
    cuisines: ['Barbecue', 'North Indian'],
    rating: 4.6,
    reviews: 2600,
    distanceLabel: '4.0 km',
    etaMinutes: 45,
    menu: [
      dish(900031, 'Chicken Tikka Platter', 'BBQ Nation', 'r_bbq', 'BBQ Nation', 349, 429, { reviews: 760 }),
      dish(900032, 'Paneer Tikka Platter', 'BBQ Nation', 'r_bbq', 'BBQ Nation', 299, 369, { veg: true, reviews: 520 }),
      dish(900033, 'Mutton Seekh Kebab', 'BBQ Nation', 'r_bbq', 'BBQ Nation', 399, 479, { reviews: 430 }),
    ],
  },
  {
    id: 'r_a2b',
    name: 'A2B Veg',
    cuisines: ['South Indian', 'Sweets'],
    rating: 4.3,
    reviews: 1900,
    distanceLabel: '2.8 km',
    etaMinutes: 30,
    menu: [
      dish(900041, 'Pongal', 'A2B Veg', 'r_a2b', 'A2B Veg', 79, 99, { veg: true, colors: _g }),
      dish(900042, 'Rava Kesari', 'A2B Veg', 'r_a2b', 'A2B Veg', 59, 75, { veg: true, colors: _g }),
    ],
  },
  {
    id: 'r_momo_hut',
    name: 'Momo Hut',
    cuisines: ['Chinese', 'Momos'],
    rating: 4.1,
    reviews: 1400,
    distanceLabel: '1.9 km',
    etaMinutes: 28,
    menu: [
      dish(900051, 'Steamed Chicken Momos', 'Momo Hut', 'r_momo_hut', 'Momo Hut', 149, 189, { reviews: 600 }),
      dish(900052, 'Veg Fried Momos', 'Momo Hut', 'r_momo_hut', 'Momo Hut', 129, 169, { veg: true, reviews: 480 }),
    ],
  },
  {
    id: 'r_cake_corner',
    name: 'Cake Corner',
    cuisines: ['Desserts', 'Bakery'],
    rating: 4.4,
    reviews: 1100,
    distanceLabel: '2.5 km',
    etaMinutes: 32,
    menu: [
      dish(900061, 'Chocolate Truffle Cake', 'Cake Corner', 'r_cake_corner', 'Cake Corner', 449, 549, { veg: true }),
      dish(900062, 'Red Velvet Pastry', 'Cake Corner', 'r_cake_corner', 'Cake Corner', 129, 159, { veg: true }),
    ],
  },
];

const restaurantById = new Map(restaurants.map((r) => [r.id, r]));

function summary(r) {
  return {
    id: r.id,
    name: r.name,
    cuisines: r.cuisines,
    rating: r.rating,
    reviews: r.reviews,
    distanceLabel: r.distanceLabel,
    etaMinutes: r.etaMinutes,
  };
}

function dishFromRow(d, restaurantName) {
  return {
    id: d.id,
    name: d.name,
    brand: d.brand,
    price: d.price,
    mrp: d.mrp,
    rating: d.rating,
    reviews: d.reviews,
    icon: d.icon,
    colors: d.colors,
    restaurantId: d.restaurant_id,
    restaurantName: restaurantName || null,
    veg: d.veg,
    egg: d.egg,
    description: d.description,
    imageUrl: d.image_url,
  };
}

function summaryFromRow(r) {
  return {
    id: r.id,
    name: r.name,
    cuisines: r.cuisines,
    rating: r.rating,
    reviews: r.reviews,
    distanceLabel: r.distance_label,
    etaMinutes: r.eta_minutes,
  };
}

// ------------------------------------------------------------ fallback API
function listRestaurants() {
  return restaurants.map(summary);
}

function getRestaurant(id) {
  const r = restaurantById.get(id);
  if (!r) return null;
  return { ...summary(r), menu: r.menu.map((d) => ({ ...d })) };
}

function menu(id) {
  const r = restaurantById.get(id);
  return r ? r.menu.map((d) => ({ ...d })) : null;
}

function searchDishes(query, limit = 60) {
  const q = String(query || '').trim().toLowerCase();
  if (!q) return [];
  const out = [];
  for (const r of restaurants) {
    for (const d of r.menu) {
      const hay = `${d.name} ${d.brand} ${d.description}`.toLowerCase();
      if (!hay.includes(q)) continue;
      out.push({ ...d, nameMatch: d.name.toLowerCase().includes(q) });
    }
  }
  out.sort((a, b) => {
    if (a.nameMatch !== b.nameMatch) return a.nameMatch ? -1 : 1;
    return b.reviews - a.reviews;
  });
  return out.slice(0, limit).map(({ nameMatch, ...rest }) => rest);
}

function searchRestaurants(query, limit = 6) {
  const q = String(query || '').trim().toLowerCase();
  if (!q) return [];
  return listRestaurants()
    .filter((r) => `${r.name} ${r.cuisines.join(' ')}`.toLowerCase().includes(q))
    .slice(0, limit);
}

// ------------------------------------------------------------ Supabase API
async function listRestaurantsDb(sb) {
  const { data, error } = await sb.from('restaurants').select('*').order('rating', { ascending: false });
  if (error) throw dbError(error, 'catalog.restaurants');
  return (data || []).map(summaryFromRow);
}

async function menuDb(sb, id) {
  const { data: r, error: rErr } = await sb
    .from('restaurants')
    .select('*')
    .eq('id', id)
    .maybeSingle();
  if (rErr) throw dbError(rErr, 'catalog.restaurant');
  if (!r) return null;
  const { data: ds, error: dErr } = await sb
    .from('dishes')
    .select('*')
    .eq('restaurant_id', id)
    .order('id', { ascending: true });
  if (dErr) throw dbError(dErr, 'catalog.menu');
  return (ds || []).map((d) => dishFromRow(d, r.name));
}

async function searchDishesDb(sb, query, limit) {
  const q = String(query || '').trim().toLowerCase();
  if (!q) return [];
  const { data, error } = await sb.from('dishes').select('*').order('id', { ascending: true });
  if (error) throw dbError(error, 'catalog.searchDishes');
  const { data: names, error: nErr } = await sb.from('restaurants').select('id, name');
  if (nErr) throw dbError(nErr, 'catalog.searchNames');
  const byId = new Map((names || []).map((r) => [r.id, r.name]));
  const out = [];
  for (const d of data || []) {
    const name = d.name.toLowerCase();
    const hay = `${d.name} ${d.brand} ${d.description}`.toLowerCase();
    if (!hay.includes(q)) continue;
    out.push({ row: d, nameMatch: name.includes(q) });
  }
  out.sort((a, b) => {
    if (a.nameMatch !== b.nameMatch) return a.nameMatch ? -1 : 1;
    return b.row.reviews - a.row.reviews;
  });
  return out
    .slice(0, limit)
    .map(({ row }) => dishFromRow(row, byId.get(row.restaurant_id)));
}

async function searchRestaurantsDb(sb, query, limit) {
  const q = String(query || '').trim().toLowerCase();
  if (!q) return [];
  const { data, error } = await sb
    .from('restaurants')
    .select('*')
    .order('rating', { ascending: false });
  if (error) throw dbError(error, 'catalog.searchRestaurants');
  return (data || [])
    .map(summaryFromRow)
    .filter((r) => `${r.name} ${r.cuisines.join(' ')}`.toLowerCase().includes(q))
    .slice(0, limit);
}

module.exports = {
  listRestaurants,
  getRestaurant,
  menu,
  searchDishes,
  searchRestaurants,
  // async wrappers — use DB when configured, else the seed above
  asyncListRestaurants: async () => {
    const sb = getSupabase();
    return sb ? listRestaurantsDb(sb) : listRestaurants();
  },
  asyncGetRestaurant: async (id) => {
    const sb = getSupabase();
    if (!sb) return getRestaurant(id);
    const { data: r, error } = await sb.from('restaurants').select('*').eq('id', id).maybeSingle();
    if (error) throw dbError(error, 'catalog.restaurant');
    if (!r) return null;
    const m = await menuDb(sb, id);
    return { ...summaryFromRow(r), menu: m };
  },
  asyncMenu: async (id) => {
    const sb = getSupabase();
    if (!sb) return menu(id);
    return menuDb(sb, id);
  },
  asyncSearchDishes: async (query, limit = 60) => {
    const sb = getSupabase();
    return sb ? searchDishesDb(sb, query, limit) : searchDishes(query, limit);
  },
  asyncSearchRestaurants: async (query, limit = 6) => {
    const sb = getSupabase();
    return sb ? searchRestaurantsDb(sb, query, limit) : searchRestaurants(query, limit);
  },
};

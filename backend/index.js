require('dotenv').config();
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');

const config = require('./config/env');

const app = express();
const PORT = config.port;

// Security middleware
app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Logging
app.use(morgan('combined'));

// Routes
const healthRoutes = require('./routes/health');
const ordersRoutes = require('./routes/orders');
const cartRoutes = require('./routes/cart');
const restaurantRoutes = require('./routes/restaurant');
const authRoutes = require('./routes/auth');
const profileRoutes = require('./routes/profile');
const walletRoutes = require('./routes/wallet');
const addressRoutes = require('./routes/address');
const pricingRoutes = require('./routes/pricing');
const checkoutRoutes = require('./routes/checkout');
const searchRoutes = require('./routes/search');
const smartChangeRoutes = require('./routes/smartChange');
const wishlistRoutes = require('./routes/wishlist');
const reviewRoutes = require('./routes/reviews');
const supportRoutes = require('./routes/support');
const notificationRoutes = require('./routes/notifications');
const couponRoutes = require('./routes/coupons');
const dineoutRoutes = require('./routes/dineout');
const errorHandler = require('./middleware/errorHandler');

app.use('/health', healthRoutes);
app.use('/orders', ordersRoutes);
app.use('/cart', cartRoutes);
app.use('/restaurants', restaurantRoutes);
app.use('/auth', authRoutes);
app.use('/profile', profileRoutes);
app.use('/wallet', walletRoutes);
app.use('/addresses', addressRoutes);
app.use('/pricing', pricingRoutes);
app.use('/checkout', checkoutRoutes);
app.use('/search', searchRoutes);
app.use('/smart-change', smartChangeRoutes);
app.use('/wishlist', wishlistRoutes);
app.use('/reviews', reviewRoutes);
app.use('/support', supportRoutes);
app.use('/notifications', notificationRoutes);
app.use('/coupons', couponRoutes);
app.use('/dineout', dineoutRoutes);

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// Centralized error handler (must be last)
app.use(errorHandler);

const { supabaseEnabled } = require('./config/supabase');

// Listen only when run directly (tests import `app` on an ephemeral port).
if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`OXRO backend running on port ${PORT}`);
    console.log(`Supabase persistence: ${supabaseEnabled() ? 'ENABLED' : 'DISABLED (in-memory fallback)'}`);
  });
}

module.exports = app;

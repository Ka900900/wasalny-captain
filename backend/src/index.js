require('dotenv').config();
const express = require('express');
const cors = require('cors');
const config = require('./config');
const uploadRoutes = require('./routes/upload.routes');
const supportRoutes = require('./routes/support.routes');
const authRoutes = require('./routes/auth.routes');
const driverRoutes = require('./routes/driver.routes');
const userRoutes = require('./routes/user.routes');

const app = express();

app.use(cors());
app.use(express.json());

// Health check
app.get('/', (req, res) => {
  res.json({ success: true, message: 'Waslny Captain backend is running' });
});

// ── Route mounting ──────────────────────────────────────────────────────────
app.use('/api/v1/auth', authRoutes);             // firebase-login, register-driver, update-phone, register-fcm-token
app.use('/api/v1/driver', driverRoutes);         // earnings, location, rides, availability
app.use('/api/v1/user', userRoutes);             // profile, ratings
app.use('/api/v1/upload', uploadRoutes);         // image uploads (profile, license, id-card, car, etc.)
app.use('/api/v1/support/messages', supportRoutes); // support chat

// Centralized error handler (e.g. multer file-filter errors)
app.use((err, req, res, next) => {
  console.error('[ERROR]', err.message);
  if (err.message === 'Only image files are allowed') {
    return res.status(400).json({ success: false, message: 'يُسمح فقط بملفات الصور' });
  }
  res.status(500).json({ success: false, message: 'خطأ داخلي في الخادم' });
});

const PORT = config.port;
app.listen(PORT, () => {
  console.log(`🚀 Waslny Captain backend listening on port ${PORT}`);
});

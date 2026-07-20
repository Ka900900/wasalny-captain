const express = require('express');
const cors = require('cors');
const config = require('./config');
const uploadRoutes = require('./routes/upload.routes');

const app = express();

app.use(cors());
app.use(express.json());

// Health check
app.get('/', (req, res) => {
  res.json({ success: true, message: 'Waslny Captain backend is running' });
});

// Image upload endpoints (JWT protected, multipart/form-data)
app.use('/api/v1/upload', uploadRoutes);

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

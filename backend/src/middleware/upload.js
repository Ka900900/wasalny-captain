const multer = require('multer');

// Store uploads in memory so we can forward the buffer to Cloudinary.
const storage = multer.memoryStorage();

const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB max
  fileFilter: (req, file, cb) => {
    if (/^image\//.test(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Only image files are allowed'), false);
    }
  },
});

// Single image field named "image" — used by every upload endpoint.
const uploadSingleImage = upload.single('image');

module.exports = { uploadSingleImage };

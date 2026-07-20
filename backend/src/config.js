require('dotenv').config();

const config = {
  port: process.env.PORT || 4000,
  jwtSecret: process.env.JWT_SECRET || 'dev-insecure-secret-change-me',
  cloudinary: {
    cloudName: process.env.CLOUDINARY_CLOUD_NAME || 'daxl7bn0m',
    apiKey: process.env.CLOUDINARY_API_KEY || '',
    apiSecret: process.env.CLOUDINARY_API_SECRET || '',
  },
  // Root folder on Cloudinary for all captain images.
  cloudinaryRoot: 'waslny_captains',
};

module.exports = config;

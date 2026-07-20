const cloudinary = require('cloudinary').v2;
const config = require('./config');

cloudinary.config({
  cloud_name: config.cloudinary.cloudName,
  api_key: config.cloudinary.apiKey,
  api_secret: config.cloudinary.apiSecret,
});

/**
 * Uploads a buffer to Cloudinary under `waslny_captains/<subFolder>`.
 *
 * @param {Buffer} buffer  - raw image bytes (from multer memory storage)
 * @param {string} subFolder - e.g. 'photos', 'licenses', 'id_cards',
 *                             'car_photos', 'insurance'
 * @returns {Promise<{secureUrl:string, publicId:string}>}
 */
async function uploadBuffer(buffer, subFolder) {
  const folder = `${config.cloudinaryRoot}/${subFolder}`;
  const result = await new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      { folder, resource_type: 'image' },
      (error, res) => {
        if (error) return reject(error);
        resolve(res);
      },
    );
    stream.end(buffer);
  });

  return {
    secureUrl: result.secure_url,
    publicId: result.public_id,
  };
}

module.exports = { uploadBuffer };

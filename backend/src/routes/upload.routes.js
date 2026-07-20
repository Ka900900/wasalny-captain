const express = require('express');
const prisma = require('../prisma');
const { uploadBuffer } = require('../cloudinary');
const { requireAuth } = require('../middleware/auth');
const { uploadSingleImage } = require('../middleware/upload');

const router = express.Router();

/**
 * Builds a unified success response and logs the upload details.
 */
function logAndRespond(res, { user, file, subFolder, result, field, publicIdField }) {
  console.log('[UPLOAD] ───────────────────────────────────────────');
  console.log(`[UPLOAD]   user      : ${user?.uid || user?.phone || 'unknown'}`);
  console.log(`[UPLOAD]   type      : ${subFolder}`);
  console.log(`[UPLOAD]   fileName  : ${file?.originalname}`);
  console.log(`[UPLOAD]   mimeType  : ${file?.mimetype}`);
  console.log(`[UPLOAD]   size      : ${file?.size} bytes`);
  console.log(`[UPLOAD]   public_id : ${result.publicId}`);
  console.log(`[UPLOAD]   secure_url: ${result.secureUrl}`);
  console.log('[UPLOAD] ───────────────────────────────────────────');

  return res.status(200).json({
    success: true,
    imageUrl: result.secureUrl,
    publicId: result.publicId,
    message: 'تم رفع الصورة بنجاح',
  });
}

/**
 * Factory that creates an upload handler for a given image type.
 *
 * @param {string} subFolder       - Cloudinary sub-folder (e.g. 'photos')
 * @param {string} urlField        - Prisma Captain column for the URL
 * @param {string} publicIdField   - Prisma Captain column for the public id
 */
function makeUploadHandler(subFolder, urlField, publicIdField) {
  return async (req, res) => {
    try {
      if (!req.file) {
        return res.status(400).json({
          success: false,
          message: 'لم يتم إرفاق صورة (الحقل: image)',
        });
      }

      const user = req.user;
      const firebaseUid = user?.uid;

      if (!firebaseUid) {
        return res.status(401).json({
          success: false,
          message: 'التوكن لا يحتوي على معرّف المستخدم',
        });
      }

      // 1) Upload to Cloudinary
      const result = await uploadBuffer(req.file.buffer, subFolder);

      // 2) Persist URL + publicId in PostgreSQL (Prisma)
      await prisma.captain.upsert({
        where: { firebaseUid },
        create: {
          firebaseUid,
          phone: user?.phone,
          [urlField]: result.secureUrl,
          [publicIdField]: result.publicId,
        },
        update: {
          [urlField]: result.secureUrl,
          [publicIdField]: result.publicId,
          updatedAt: new Date(),
        },
      });

      // 3) Return unified response + logging
      return logAndRespond(res, {
        user,
        file: req.file,
        subFolder,
        result,
        field: urlField,
        publicIdField,
      });
    } catch (err) {
      console.error('[UPLOAD] ❌ Exception while uploading image');
      console.error(`[UPLOAD]   type     : ${subFolder}`);
      console.error(`[UPLOAD]   user     : ${req.user?.uid || 'unknown'}`);
      console.error(`[UPLOAD]   error    : ${err.message}`);
      console.error(err.stack);
      return res.status(500).json({
        success: false,
        message: 'حدث خطأ أثناء رفع الصورة',
      });
    }
  };
}

// ── Endpoints (all protected by JWT + upload.single('image')) ──
router.post(
  '/profile',
  requireAuth,
  uploadSingleImage,
  makeUploadHandler('photos', 'photoUrl', 'photoPublicId'),
);
router.post(
  '/license',
  requireAuth,
  uploadSingleImage,
  makeUploadHandler('licenses', 'licenseUrl', 'licensePublicId'),
);
router.post(
  '/id-card',
  requireAuth,
  uploadSingleImage,
  makeUploadHandler('id_cards', 'idCardUrl', 'idCardPublicId'),
);
router.post(
  '/car',
  requireAuth,
  uploadSingleImage,
  makeUploadHandler('car_photos', 'carPhotoUrl', 'carPhotoPublicId'),
);
router.post(
  '/insurance',
  requireAuth,
  uploadSingleImage,
  makeUploadHandler('insurance', 'insuranceUrl', 'insurancePublicId'),
);

module.exports = router;

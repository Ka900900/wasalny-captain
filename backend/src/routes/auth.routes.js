/**
 * Waslny Captain — Auth Routes
 *
 * Provides:
 *   POST /api/v1/auth/firebase-login      — Exchange Firebase ID Token → App JWT
 *   POST /api/v1/auth/register-driver      — Register/update driver vehicle info
 *   POST /api/v1/auth/register-fcm-token   — Save FCM token for push notifications
 *
 * @see Flutter ApiService.registerDriver()
 * @see Flutter AuthService.loginWithBackend()
 */

const express = require('express');
const jwt = require('jsonwebtoken');
const admin = require('firebase-admin');
const prisma = require('../prisma');
const config = require('../config');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

// ═════════════════════════════════════════════════════════════════════════════
// Firebase Admin Initialization
// ═════════════════════════════════════════════════════════════════════════════

if (!admin.apps.length) {
  try {
    // Try explicit service account credentials from env vars
    if (process.env.FIREBASE_PROJECT_ID && process.env.FIREBASE_CLIENT_EMAIL && process.env.FIREBASE_PRIVATE_KEY) {
      admin.initializeApp({
        credential: admin.credential.cert({
          projectId: process.env.FIREBASE_PROJECT_ID,
          clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
          privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
        }),
      });
      console.log('[AUTH] ✅ Firebase Admin initialized with explicit credentials');
    } else {
      // Fall back to application default credentials
      admin.initializeApp();
      console.log('[AUTH] ✅ Firebase Admin initialized with default credentials');
    }
  } catch (err) {
    console.error('[AUTH] ❌ Firebase Admin initialization failed:', err.message);
    console.error('[AUTH]   Firebase token verification will NOT work until this is fixed.');
    console.error('[AUTH]   Set FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY env vars.');
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Helpers
// ═════════════════════════════════════════════════════════════════════════════

/**
 * Generates an application JWT for the given captain.
 */
function generateAppJWT(captain) {
  return jwt.sign(
    {
      userId: captain.firebaseUid,
      uid: captain.firebaseUid,       // backward compat with upload routes
      phone: captain.phone,
      role: captain.role || 'DRIVER',
    },
    config.jwtSecret,
    { expiresIn: '365d' },
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// POST /firebase-login
// ═════════════════════════════════════════════════════════════════════════════
// Exchanges a Firebase ID Token for the app's own JWT.
// Called by Flutter: AuthService.loginWithBackend()
//
// Body: { firebaseIdToken: string, name?: string, email?: string, photoUrl?: string }
// Response: { success: true, token: string, captain: {...} }
// ═════════════════════════════════════════════════════════════════════════════

router.post('/firebase-login', async (req, res) => {
  try {
    const { firebaseIdToken, name, email, photoUrl } = req.body;

    console.log('[AUTH] ─── POST /firebase-login ───────────────────────');
    console.log(`[AUTH]   firebaseIdToken: ${firebaseIdToken ? firebaseIdToken.substring(0, 30) + '...' : 'MISSING'}`);
    console.log(`[AUTH]   name: ${name || '(none)'}`);
    console.log(`[AUTH]   email: ${email || '(none)'}`);

    // ── Validate ──────────────────────────────────────────────────
    if (!firebaseIdToken) {
      console.log('[AUTH] ❌ 400 — firebaseIdToken is required');
      return res.status(400).json({
        success: false,
        error: 'firebaseIdToken is required',
      });
    }

    // ── Verify Firebase token ─────────────────────────────────────
    let decoded;
    try {
      decoded = await admin.auth().verifyIdToken(firebaseIdToken);
    } catch (verifyErr) {
      console.error('[AUTH] ❌ Firebase token verification failed:', verifyErr.message);
      return res.status(401).json({
        success: false,
        error: 'Invalid or expired Firebase token',
      });
    }

    const firebaseUid = decoded.uid;
    const firebasePhone = decoded.phone_number || null;
    console.log(`[AUTH]   Firebase UID: ${firebaseUid}`);
    console.log(`[AUTH]   Firebase phone: ${firebasePhone || '(none)'}`);

    // ── Upsert Captain in PostgreSQL ──────────────────────────────
    console.log('[AUTH]   Upserting Captain in PostgreSQL...');
    const captain = await prisma.captain.upsert({
      where: { firebaseUid },
      create: {
        firebaseUid,
        phone: firebasePhone,
        name: name || null,
        email: email || null,
        photoUrl: photoUrl || null,
        role: 'DRIVER',
      },
      update: {
        // Always update these fields on login (they might have changed)
        name: name || undefined,
        email: email || undefined,
        photoUrl: photoUrl || undefined,
        phone: firebasePhone || undefined,
        updatedAt: new Date(),
      },
    });

    console.log(`[AUTH]   Captain upserted: id=${captain.id}, firebaseUid=${captain.firebaseUid}`);

    // ── Generate app JWT ──────────────────────────────────────────
    const token = generateAppJWT(captain);

    console.log('[AUTH] ✅ Login successful');
    console.log('[AUTH] ────────────────────────────────────────────────');

    return res.status(200).json({
      success: true,
      token,
      captain: {
        id: captain.id,
        firebaseUid: captain.firebaseUid,
        phone: captain.phone,
        name: captain.name,
        email: captain.email,
        role: captain.role,
        vehicleType: captain.vehicleType,
        vehicleModel: captain.vehicleModel,
        vehicleColor: captain.vehicleColor,
        vehicleNumber: captain.vehicleNumber,
        photoUrl: captain.photoUrl,
      },
    });
  } catch (err) {
    console.error('[AUTH] ❌ POST /firebase-login — UNHANDLED ERROR');
    console.error('[AUTH]   Error:', err.message);
    console.error('[AUTH]   Stack:', err.stack);
    return res.status(500).json({
      success: false,
      error: 'Internal server error during login',
    });
  }
});

// ═════════════════════════════════════════════════════════════════════════════
// POST /register-driver
// ═════════════════════════════════════════════════════════════════════════════
// Registers or updates driver vehicle info.
// Called by Flutter: ApiService.registerDriver()
//
// Body: {
//   role: "DRIVER",
//   carModel: string,          → mapped to vehicleModel
//   carPlateNumber: string,    → mapped to vehicleNumber
//   carColor: string,          → mapped to vehicleColor
//   vehicleType: string,       → PRIVATE_CAR | TAXI | SCOOTER | MOTORCYCLE
//   carPhotoUrl: string,
//   name?: string,
//   email?: string,
//   photoUrl?: string,
//   phoneNumber?: string,      → mapped to phone
//   nationalId?: string,
//   idCardUrl?: string,
//   idCardBackUrl?: string,
//   licenseUrl?: string,
//   licenseBackUrl?: string,
//   licenseNumber?: string,
//   criminalRecordUrl?: string,
//   drugTestUrl?: string,
// }
//
// Response: { success: true, token: string, captain: {...} }
// ═════════════════════════════════════════════════════════════════════════════

router.post('/register-driver', requireAuth, async (req, res) => {
  try {
    const firebaseUid = req.user.userId || req.user.uid;

    console.log('[AUTH] ─── POST /register-driver ──────────────────────');
    console.log(`[AUTH]   firebaseUid: ${firebaseUid}`);
    console.log(`[AUTH]   Full request body:`);
    console.log(`[AUTH]     role:            ${req.body.role}`);
    console.log(`[AUTH]     carModel:        ${req.body.carModel}`);
    console.log(`[AUTH]     carPlateNumber:  ${req.body.carPlateNumber}`);
    console.log(`[AUTH]     carColor:        ${req.body.carColor}`);
    console.log(`[AUTH]     vehicleType:     ${req.body.vehicleType}`);
    console.log(`[AUTH]     carPhotoUrl:     ${req.body.carPhotoUrl ? req.body.carPhotoUrl.substring(0, 50) + '...' : 'EMPTY'}`);
    console.log(`[AUTH]     name:            ${req.body.name || '(none)'}`);
    console.log(`[AUTH]     email:           ${req.body.email || '(none)'}`);
    console.log(`[AUTH]     photoUrl:        ${req.body.photoUrl ? 'present' : '(none)'}`);
    console.log(`[AUTH]     phoneNumber:     ${req.body.phoneNumber || '(none)'}`);
    console.log(`[AUTH]     nationalId:      ${req.body.nationalId || '(none)'}`);
    console.log(`[AUTH]     idCardUrl:       ${req.body.idCardUrl ? 'present' : '(none)'}`);
    console.log(`[AUTH]     idCardBackUrl:   ${req.body.idCardBackUrl ? 'present' : '(none)'}`);
    console.log(`[AUTH]     licenseUrl:      ${req.body.licenseUrl ? 'present' : '(none)'}`);
    console.log(`[AUTH]     licenseBackUrl:  ${req.body.licenseBackUrl ? 'present' : '(none)'}`);
    console.log(`[AUTH]     licenseNumber:   ${req.body.licenseNumber || '(none)'}`);
    console.log(`[AUTH]     criminalRecordUrl: ${req.body.criminalRecordUrl ? 'present' : '(none)'}`);
    console.log(`[AUTH]     drugTestUrl:     ${req.body.drugTestUrl ? 'present' : '(none)'}`);

    // ── Validate required fields ──────────────────────────────────
    const {
      carModel,
      carPlateNumber,
      carColor,
      vehicleType,
      carPhotoUrl,
      name,
      email,
      photoUrl,
      phoneNumber,
      nationalId,
      idCardUrl,
      idCardBackUrl,
      licenseUrl,
      licenseBackUrl,
      licenseNumber,
      criminalRecordUrl,
      drugTestUrl,
      role,
    } = req.body;

    const missingFields = [];
    if (!carModel) missingFields.push('carModel');
    if (!carPlateNumber) missingFields.push('carPlateNumber');
    if (!carColor) missingFields.push('carColor');
    if (!vehicleType) missingFields.push('vehicleType');

    if (missingFields.length > 0) {
      console.log(`[AUTH] ❌ 400 — Missing required fields: ${missingFields.join(', ')}`);
      return res.status(400).json({
        success: false,
        error: `Missing required fields: ${missingFields.join(', ')}`,
        missingFields,
      });
    }

    // ── Validate vehicleType enum ─────────────────────────────────
    const validVehicleTypes = ['PRIVATE_CAR', 'TAXI', 'SCOOTER', 'MOTORCYCLE'];
    if (!validVehicleTypes.includes(vehicleType)) {
      console.log(`[AUTH] ❌ 400 — Invalid vehicleType: "${vehicleType}". Must be one of: ${validVehicleTypes.join(', ')}`);
      return res.status(400).json({
        success: false,
        error: `Invalid vehicleType: "${vehicleType}". Must be one of: ${validVehicleTypes.join(', ')}`,
      });
    }

    if (!firebaseUid) {
      console.log('[AUTH] ❌ 401 — No firebaseUid in JWT');
      return res.status(401).json({
        success: false,
        error: 'Unauthorized: no user ID in token',
      });
    }

    // ── Map Flutter field names → Prisma field names ──────────────
    const updateData = {
      // Vehicle fields (mapped from Flutter camelCase → Prisma camelCase)
      vehicleModel: carModel,
      vehicleNumber: carPlateNumber,
      vehicleColor: carColor,
      vehicleType: vehicleType,
      carPhotoUrl: carPhotoUrl || null,
      updatedAt: new Date(),
    };

    // Optional fields
    if (name) updateData.name = name;
    if (email) updateData.email = email;
    if (photoUrl) updateData.photoUrl = photoUrl;
    if (phoneNumber) updateData.phone = phoneNumber;
    if (nationalId) updateData.nationalId = nationalId;
    if (idCardUrl) updateData.idCardUrl = idCardUrl;
    if (idCardBackUrl) updateData.idCardBackUrl = idCardBackUrl;
    if (licenseUrl) updateData.licenseUrl = licenseUrl;
    if (licenseBackUrl) updateData.licenseBackUrl = licenseBackUrl;
    if (licenseNumber) updateData.licenseNumber = licenseNumber;
    if (role) updateData.role = role;
    if (criminalRecordUrl) updateData.criminalRecordUrl = criminalRecordUrl;
    if (drugTestUrl) updateData.drugTestUrl = drugTestUrl;

    console.log('[AUTH]   Mapped update data for Prisma:');
    console.log('[AUTH]     vehicleModel:', updateData.vehicleModel);
    console.log('[AUTH]     vehicleNumber:', updateData.vehicleNumber);
    console.log('[AUTH]     vehicleColor:', updateData.vehicleColor);
    console.log('[AUTH]     vehicleType:', updateData.vehicleType);
    console.log('[AUTH]     phone:', updateData.phone || '(unchanged)');

    // ── Upsert Captain in PostgreSQL ──────────────────────────────
    console.log('[AUTH]   Calling prisma.captain.upsert...');
    const captain = await prisma.captain.upsert({
      where: { firebaseUid },
      create: {
        firebaseUid,
        phone: phoneNumber || null,
        name: name || null,
        email: email || null,
        role: role || 'DRIVER',
        vehicleType,
        vehicleModel: carModel,
        vehicleColor: carColor,
        vehicleNumber: carPlateNumber,
        carPhotoUrl: carPhotoUrl || null,
        photoUrl: photoUrl || null,
        nationalId: nationalId || null,
        idCardUrl: idCardUrl || null,
        idCardBackUrl: idCardBackUrl || null,
        licenseUrl: licenseUrl || null,
        licenseBackUrl: licenseBackUrl || null,
        licenseNumber: licenseNumber || null,
        criminalRecordUrl: criminalRecordUrl || null,
        drugTestUrl: drugTestUrl || null,
      },
      update: updateData,
    });

    console.log(`[AUTH] ✅ Captain upserted successfully: id=${captain.id}`);
    console.log(`[AUTH]   vehicleType=${captain.vehicleType}, vehicleModel=${captain.vehicleModel}`);
    console.log(`[AUTH]   vehicleColor=${captain.vehicleColor}, vehicleNumber=${captain.vehicleNumber}`);

    // ── Generate new JWT (in case fields changed) ─────────────────
    const token = generateAppJWT(captain);

    console.log('[AUTH] ✅ Registration successful');
    console.log('[AUTH] ────────────────────────────────────────────────');

    return res.status(200).json({
      success: true,
      token,
      message: 'تم تسجيل المركبة بنجاح',
      captain: {
        id: captain.id,
        firebaseUid: captain.firebaseUid,
        phone: captain.phone,
        name: captain.name,
        role: captain.role,
        vehicleType: captain.vehicleType,
        vehicleModel: captain.vehicleModel,
        vehicleColor: captain.vehicleColor,
        vehicleNumber: captain.vehicleNumber,
        carPhotoUrl: captain.carPhotoUrl,
        photoUrl: captain.photoUrl,
      },
    });
  } catch (err) {
    // ── Prisma-specific error handling ────────────────────────────
    if (err.code) {
      console.error(`[AUTH] ❌ Prisma error code: ${err.code}`);
      switch (err.code) {
        case 'P2002':
          console.error('[AUTH]   Unique constraint violation');
          console.error(`[AUTH]   Field: ${err.meta?.target || 'unknown'}`);
          return res.status(409).json({
            success: false,
            error: `A record with this ${err.meta?.target || 'field'} already exists`,
            prismaCode: 'P2002',
          });
        case 'P2003':
          console.error('[AUTH]   Foreign key constraint violation');
          return res.status(400).json({
            success: false,
            error: 'Referenced record does not exist',
            prismaCode: 'P2003',
          });
        case 'P2025':
          console.error('[AUTH]   Record not found for update');
          return res.status(404).json({
            success: false,
            error: 'Captain record not found',
            prismaCode: 'P2025',
          });
        default:
          console.error(`[AUTH]   Unhandled Prisma error: ${err.message}`);
      }
    }

    console.error('[AUTH] ❌ POST /register-driver — UNHANDLED ERROR');
    console.error('[AUTH]   Error:', err.message);
    console.error('[AUTH]   Stack:', err.stack);
    return res.status(500).json({
      success: false,
      error: 'Internal server error during driver registration',
      details: err.message,
    });
  }
});

// ═════════════════════════════════════════════════════════════════════════════
// POST /register-fcm-token
// ═════════════════════════════════════════════════════════════════════════════
// Saves the captain's FCM token for push notifications.
// Called by Flutter: NotificationService.registerTokenWithBackend()
//
// Body: { fcmToken: string }
// ═════════════════════════════════════════════════════════════════════════════

router.post('/register-fcm-token', requireAuth, async (req, res) => {
  try {
    const firebaseUid = req.user.userId || req.user.uid;
    const { fcmToken } = req.body;

    console.log(`[AUTH] POST /register-fcm-token — uid=${firebaseUid}, token=${fcmToken ? fcmToken.substring(0, 20) + '...' : 'MISSING'}`);

    if (!fcmToken) {
      return res.status(400).json({ success: false, error: 'fcmToken is required' });
    }

    // Store FCM token (upsert to avoid duplicates)
    // We store it as a simple field for now; in production you might want
    // a separate FCMToken model for multiple devices.
    await prisma.captain.upsert({
      where: { firebaseUid },
      create: { firebaseUid, fcmToken },
      update: { fcmToken, updatedAt: new Date() },
    });

    console.log(`[AUTH] ✅ FCM token saved for uid=${firebaseUid}`);
    return res.status(200).json({ success: true, message: 'FCM token registered' });
  } catch (err) {
    console.error('[AUTH] ❌ register-fcm-token error:', err.message);
    return res.status(500).json({ success: false, error: 'Failed to register FCM token' });
  }
});

module.exports = router;

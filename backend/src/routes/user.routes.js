/**
 * Waslny Captain — User Routes
 *
 * Provides:
 *   GET  /api/v1/user/profile      — Get current user profile
 *   PUT  /api/v1/user/profile/update — Update user profile
 *   GET  /api/v1/user/ratings/:id  — Get driver ratings
 */

const express = require('express');
const prisma = require('../prisma');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

// ── GET /profile ────────────────────────────────────────────────────────────
router.get('/profile', requireAuth, async (req, res) => {
  try {
    const firebaseUid = req.user.userId || req.user.uid;
    console.log(`[USER] GET /profile — uid=${firebaseUid}`);

    const captain = await prisma.captain.findUnique({
      where: { firebaseUid },
    });

    if (!captain) {
      return res.status(404).json({ success: false, error: 'Profile not found' });
    }

    return res.status(200).json({
      success: true,
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
        licenseNumber: captain.licenseNumber,
        photoUrl: captain.photoUrl,
        carPhotoUrl: captain.carPhotoUrl,
        licenseUrl: captain.licenseUrl,
        licenseBackUrl: captain.licenseBackUrl,
        idCardUrl: captain.idCardUrl,
        idCardBackUrl: captain.idCardBackUrl,
        insuranceUrl: captain.insuranceUrl,
        criminalRecordUrl: captain.criminalRecordUrl,
        drugTestUrl: captain.drugTestUrl,
        rating: captain.rating,
        createdAt: captain.createdAt,
        updatedAt: captain.updatedAt,
      },
    });
  } catch (err) {
    console.error('[USER] ❌ GET /profile error:', err.message);
    return res.status(500).json({ success: false, error: 'Failed to fetch profile' });
  }
});

// ── PUT /profile/update ─────────────────────────────────────────────────────
router.put('/profile/update', requireAuth, async (req, res) => {
  try {
    const firebaseUid = req.user.userId || req.user.uid;
    const { firstName, lastName, avatarUrl } = req.body;

    console.log(`[USER] PUT /profile/update — uid=${firebaseUid}`);
    console.log(`[USER]   firstName: ${firstName || '(none)'}`);
    console.log(`[USER]   lastName: ${lastName || '(none)'}`);
    console.log(`[USER]   avatarUrl: ${avatarUrl ? 'present' : '(none)'}`);

    const updateData = { updatedAt: new Date() };
    if (firstName) updateData.name = firstName;
    if (lastName) updateData.name = [firstName, lastName].filter(Boolean).join(' ');
    if (avatarUrl) updateData.photoUrl = avatarUrl;

    const captain = await prisma.captain.upsert({
      where: { firebaseUid },
      create: {
        firebaseUid,
        name: firstName || null,
        photoUrl: avatarUrl || null,
      },
      update: updateData,
    });

    console.log(`[USER] ✅ Profile updated: ${captain.id}`);
    return res.status(200).json({ success: true, message: 'Profile updated' });
  } catch (err) {
    console.error('[USER] ❌ PUT /profile/update error:', err.message);
    return res.status(500).json({ success: false, error: 'Failed to update profile' });
  }
});

// ── GET /ratings/:id ────────────────────────────────────────────────────────
router.get('/ratings/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params;
    console.log(`[USER] GET /ratings/${id}`);

    // TODO: Implement real ratings from a ratings table
    return res.status(200).json({
      success: true,
      summary: { average: 0, count: 0 },
      ratings: [],
    });
  } catch (err) {
    console.error('[USER] ❌ GET /ratings error:', err.message);
    return res.status(500).json({ success: false, error: 'Failed to fetch ratings' });
  }
});

module.exports = router;

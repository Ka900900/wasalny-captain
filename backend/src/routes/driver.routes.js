/**
 * Waslny Captain — Driver Routes
 *
 * Provides:
 *   GET  /api/v1/driver/earnings       — Earnings summary (also used to check if driver exists)
 *   PUT  /api/v1/driver/location       — Update driver location
 *   GET  /api/v1/driver/available-rides — Get nearby available rides
 *   POST /api/v1/driver/accept-ride/:id — Accept a ride
 *   PUT  /api/v1/driver/ride/start/:id  — Start a ride
 *   PUT  /api/v1/driver/ride/arrive/:id — Arrive at pickup
 *   PUT  /api/v1/driver/ride/complete/:id — Complete a ride
 *   POST /api/v1/driver/toggle-availability — Toggle online/offline
 */

const express = require('express');
const prisma = require('../prisma');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

// ── GET /earnings ───────────────────────────────────────────────────────────
// Returns earnings summary. Also used by Flutter's `isDriverRegistered()`
// to check if a driver profile exists (200 = exists, 404 = not found).
router.get('/earnings', requireAuth, async (req, res) => {
  try {
    const firebaseUid = req.user.userId || req.user.uid;
    const { period } = req.query; // daily | weekly | monthly

    console.log(`[DRIVER] GET /earnings — uid=${firebaseUid}, period=${period}`);

    const captain = await prisma.captain.findUnique({
      where: { firebaseUid },
    });

    if (!captain) {
      console.log(`[DRIVER] ❌ 404 — Captain not found: ${firebaseUid}`);
      return res.status(404).json({
        success: false,
        error: 'Captain profile not found',
      });
    }

    // TODO: Implement real earnings calculation from ride data
    // For now, return a placeholder
    return res.status(200).json({
      success: true,
      period: period || 'daily',
      totalEarnings: 0,
      rideCount: 0,
      averageRating: captain.rating || 0,
    });
  } catch (err) {
    console.error('[DRIVER] ❌ GET /earnings error:', err.message);
    return res.status(500).json({ success: false, error: 'Failed to fetch earnings' });
  }
});

// ── PUT /location ───────────────────────────────────────────────────────────
router.put('/location', requireAuth, async (req, res) => {
  try {
    const firebaseUid = req.user.userId || req.user.uid;
    const { lat, lng } = req.body;

    console.log(`[DRIVER] PUT /location — uid=${firebaseUid}, lat=${lat}, lng=${lng}`);

    if (lat == null || lng == null) {
      return res.status(400).json({ success: false, error: 'lat and lng are required' });
    }

    // TODO: Store location in a driver_locations table or Redis
    return res.status(200).json({ success: true, message: 'Location updated' });
  } catch (err) {
    console.error('[DRIVER] ❌ PUT /location error:', err.message);
    return res.status(500).json({ success: false, error: 'Failed to update location' });
  }
});

// ── GET /available-rides ────────────────────────────────────────────────────
router.get('/available-rides', requireAuth, async (req, res) => {
  try {
    console.log('[DRIVER] GET /available-rides');
    // TODO: Implement ride matching logic
    return res.status(200).json({ success: true, rides: [] });
  } catch (err) {
    console.error('[DRIVER] ❌ GET /available-rides error:', err.message);
    return res.status(500).json({ success: false, error: 'Failed to fetch rides' });
  }
});

// ── POST /accept-ride/:id ──────────────────────────────────────────────────
router.post('/accept-ride/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params;
    console.log(`[DRIVER] POST /accept-ride/${id}`);
    // TODO: Implement ride acceptance
    return res.status(200).json({ success: true, message: 'Ride accepted' });
  } catch (err) {
    console.error('[DRIVER] ❌ POST /accept-ride error:', err.message);
    return res.status(500).json({ success: false, error: 'Failed to accept ride' });
  }
});

// ── PUT /ride/start/:id ────────────────────────────────────────────────────
router.put('/ride/start/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params;
    console.log(`[DRIVER] PUT /ride/start/${id}`);
    return res.status(200).json({ success: true, message: 'Ride started' });
  } catch (err) {
    console.error('[DRIVER] ❌ PUT /ride/start error:', err.message);
    return res.status(500).json({ success: false, error: 'Failed to start ride' });
  }
});

// ── PUT /ride/arrive/:id ───────────────────────────────────────────────────
router.put('/ride/arrive/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params;
    console.log(`[DRIVER] PUT /ride/arrive/${id}`);
    return res.status(200).json({ success: true, message: 'Arrived at pickup' });
  } catch (err) {
    console.error('[DRIVER] ❌ PUT /ride/arrive error:', err.message);
    return res.status(500).json({ success: false, error: 'Failed to arrive' });
  }
});

// ── PUT /ride/complete/:id ─────────────────────────────────────────────────
router.put('/ride/complete/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params;
    console.log(`[DRIVER] PUT /ride/complete/${id}`);
    return res.status(200).json({ success: true, message: 'Ride completed' });
  } catch (err) {
    console.error('[DRIVER] ❌ PUT /ride/complete error:', err.message);
    return res.status(500).json({ success: false, error: 'Failed to complete ride' });
  }
});

// ── POST /toggle-availability ───────────────────────────────────────────────
router.post('/toggle-availability', requireAuth, async (req, res) => {
  try {
    const firebaseUid = req.user.userId || req.user.uid;
    const { isAvailable } = req.body;
    console.log(`[DRIVER] POST /toggle-availability — uid=${firebaseUid}, isAvailable=${isAvailable}`);
    // TODO: Store availability in DB or Redis
    return res.status(200).json({ success: true, isAvailable });
  } catch (err) {
    console.error('[DRIVER] ❌ POST /toggle-availability error:', err.message);
    return res.status(500).json({ success: false, error: 'Failed to toggle availability' });
  }
});

module.exports = router;

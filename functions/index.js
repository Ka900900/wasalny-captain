/**
 * Waslny Captain – Firebase Cloud Functions
 *
 * Secure backend for creating Kashier payment sessions.
 * The Kashier API secret key is stored here, not in the mobile app.
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// ═════════════════════════════════════════════════════════════════════════════
// CONFIGURATION – Replace with your Kashier credentials
// ═════════════════════════════════════════════════════════════════════════════

const KASHIER_API_KEY = 'c56016bb-6cf9-45ec-afb8-53f7711f10f3';
const KASHIER_SECRET_KEY = '3b7331769bb77340fdca98dfd5bad3d9$3c98cef1d6eb36a42dd78b3d718eb8524c01a2f94b6b45584cb11f4dd5baec083249f6aca5579430693dd154a993dc57';
const KASHIER_MERCHANT_ID = 'MID-44432-850';
const KASHIER_BASE_URL = 'https://test-api.kashier.io/v3'; // → https://api.kashier.io/v3 for live

// ═════════════════════════════════════════════════════════════════════════════
// createKashierSession – Callable Function
// ═════════════════════════════════════════════════════════════════════════════

/**
 * Creates a Kashier payment session for wallet top-up.
 *
 * Called from the Flutter app:
 *   FirebaseFunctions.instance.httpsCallable('createKashierSession').call({
 *     amount: '100.00',
 *     currency: 'EGP',
 *     uid: 'driver_uid',
 *   });
 *
 * Returns { sessionId: string } on success.
 */
exports.createKashierSession = functions.https.onCall(async (data, context) => {
  // ── Authentication check ──────────────────────────────────────────────────
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'يجب تسجيل الدخول أولاً',
    );
  }

  const uid = context.auth.uid;
  const { amount, currency } = data;

  // ── Validation ────────────────────────────────────────────────────────────
  if (!amount || amount <= 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'المبلغ غير صالح',
    );
  }

  if (amount > 10000) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'الحد الأقصى للشحن هو 10,000 ج.م',
    );
  }

  const orderId = `waslny_${uid.substring(0, 8)}_${Date.now()}`;

  // ── Build request ─────────────────────────────────────────────────────────
  const sessionPayload = {
    amount: amount.toString(),
    currency: currency || 'EGP',
    order: orderId,
    merchantId: KASHIER_MERCHANT_ID,
    mode: 'test', // → 'live' for production
    type: 'one-time',
    paymentType: 'credit',
    display: 'ar',
    allowedMethods: 'card,wallet',
    expireAt: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
    maxFailureAttempts: 3,
    metaData: JSON.stringify({
      driverUid: uid,
      source: 'waslny_captain_topup',
    }),
  };

  // ── Call Kashier API ──────────────────────────────────────────────────────
  try {
    const response = await fetch(`${KASHIER_BASE_URL}/payment/sessions`, {
      method: 'POST',
      headers: {
        Authorization: KASHIER_SECRET_KEY,
        'api-key': KASHIER_API_KEY,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(sessionPayload),
    });

    const result = await response.json();

    if (!response.ok) {
      functions.logger.error('Kashier session error', result);
      throw new functions.https.HttpsError(
        'internal',
        'فشل إنشاء جلسة الدفع',
      );
    }

    return { sessionId: result._id };
  } catch (error) {
    functions.logger.error('createKashierSession error', error);
    throw new functions.https.HttpsError(
      'internal',
      'حدث خطأ أثناء إنشاء جلسة الدفع',
    );
  }
});

// ═════════════════════════════════════════════════════════════════════════════
// kashierWebhook – Handles payment status updates
// ═════════════════════════════════════════════════════════════════════════════

/**
 * Webhook endpoint that Kashier calls when a payment status changes.
 *
 * Configure this URL in your Kashier dashboard:
 *   https://REGION-PROJECT.cloudfunctions.net/kashierWebhook
 *
 * The webhook updates the driver's wallet balance and records the
 * transaction in Firestore.
 */
exports.kashierWebhook = functions.https.onRequest(async (req, res) => {
  // Only accept POST
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  try {
    const event = req.body;

    functions.logger.info('Kashier webhook received', event);

    // ── Extract data ──────────────────────────────────────────────────────
    const { sessionId, status, order, amount } = event;

    if (!sessionId || !status) {
      res.status(400).send('Missing required fields');
      return;
    }

    // We only care about successful payments
    if (status !== 'PAID' && status !== 'SUCCESS' && status !== 'CAPTURED') {
      res.status(200).send('Ignored');
      return;
    }

    // Extract driver UID from metadata (passed during session creation)
    let driverUid = '';
    try {
      const metadata =
        event.metaData && typeof event.metaData === 'string'
          ? JSON.parse(event.metaData)
          : event.metaData || {};
      driverUid = metadata.driverUid || '';
    } catch (_) {
      // fallback: try to extract from order ID
      driverUid = order ? order.split('_')[1] || '' : '';
    }

    if (!driverUid) {
      functions.logger.error('Could not determine driver UID from webhook');
      res.status(200).send('Missing driver UID');
      return;
    }

    // ── Update wallet ─────────────────────────────────────────────────────
    const walletRef = admin.firestore().doc(`wallets/${driverUid}`);
    const txRef = walletRef.collection('transactions');

    await admin.firestore().runTransaction(async (transaction) => {
      const walletDoc = await transaction.get(walletRef);
      const currentBalance = walletDoc.data()?.balance || 0;
      const newBalance = currentBalance + parseFloat(amount || '0');

      transaction.set(
        walletRef,
        { balance: newBalance, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
        { merge: true },
      );

      transaction.add(txRef, {
        type: 'payment',
        amount: parseFloat(amount || '0'),
        description: 'شحن المحفظة عبر Kashier',
        status: 'completed',
        kashierSessionId: sessionId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    functions.logger.info(
      `Wallet updated for driver ${driverUid}: +${amount}`,
    );
    res.status(200).json({ received: true });
  } catch (error) {
    functions.logger.error('kashierWebhook error', error);
    res.status(500).send('Internal Server Error');
  }
});

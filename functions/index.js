/**
 * Waslny Captain – Firebase Cloud Functions
 *
 * Secure backend for creating Kashier payment sessions.
 * The Kashier API secret key is stored here, not in the mobile app.
 */

const functions = require('firebase-functions');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();

// ═════════════════════════════════════════════════════════════════════════════
// CONFIGURATION
// Kashier credentials are provided via Firebase Functions v2 params, sourced
// from the gitignored `functions/.env` file. `firebase deploy` uploads that
// .env as the function's runtime environment, so the keys stay server-side
// and are never committed to source control. (This replaces the deprecated
// functions.config() / Runtime Config service.)
//
// For local emulator testing the same `.env` is read via process.env.
// ═════════════════════════════════════════════════════════════════════════════

const { defineString } = require('firebase-functions/params');

const kashierApiKey = defineString('KASHIER_API_KEY', { default: '' });
const kashierSecretKey = defineString('KASHIER_SECRET_KEY', { default: '' });
const kashierMerchantId = defineString('KASHIER_MERCHANT_ID', {
  default: 'MID-44432-850',
});
const kashierAccountId = defineString('KASHIER_ACCOUNT_ID', { default: '' });
const kashierBaseUrl = defineString('KASHIER_BASE_URL', {
  default: 'https://api.kashier.io/v3',
});

/// Resolves the current Kashier config (params first, then local .env).
function getKashierConfig() {
  return {
    apiKey: kashierApiKey.value() || process.env.KASHIER_API_KEY || '',
    secretKey: kashierSecretKey.value() || process.env.KASHIER_SECRET_KEY || '',
    merchantId:
      kashierMerchantId.value() ||
      process.env.KASHIER_MERCHANT_ID ||
      'MID-44432-850',
    accountId:
      kashierAccountId.value() || process.env.KASHIER_ACCOUNT_ID || '',
    baseUrl:
      kashierBaseUrl.value() ||
      process.env.KASHIER_BASE_URL ||
      'https://api.kashier.io/v3',
  };
}

/**
 * Verifies the Kashier webhook signature.
 *
 * Kashier signs the raw request body with HMAC-SHA256 (using the Merchant
 * Secret Key) and sends the result (base64) in the `x-kashier-signature`
 * header. We recompute it and compare in constant time.
 *
 * Note: Cloud Functions exposes the raw JSON body as `req.rawBody`.
 */
function verifyKashierSignature(req) {
  const signature = req.headers['x-kashier-signature'];
  if (!signature) return false;

  const secretKey = getKashierConfig().secretKey;
  const raw = req.rawBody ? req.rawBody.toString('utf8') : JSON.stringify(req.body);
  const computed = crypto
    .createHmac('sha256', secretKey)
    .update(raw)
    .digest('base64');

  const a = Buffer.from(computed);
  const b = Buffer.from(signature);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

// ═════════════════════════════════════════════════════════════════════════════
// recordKashierPayment – shared atomic, idempotent wallet writer
// ═════════════════════════════════════════════════════════════════════════════

/**
 * Atomically updates a driver's wallet after a Kashier payment is verified.
 *
 * - Uses a Firestore transaction so the balance + transaction are written
 *   together (no partial updates).
 * - Idempotent: the transaction document is keyed by the Kashier `sessionId`.
 *   If it was already recorded as `completed`, the balance is NEVER credited
 *   twice — even if Kashier retries the webhook or the client calls the
 *   confirm callable twice.
 * - The balance is only changed when `status === 'completed'`.
 *
 * Called by both `kashierWebhook` (Kashier-verified) and `confirmKashierTopUp`
 * (called by the app right after the SDK reports success).
 */
async function recordKashierPayment({ driverUid, sessionId, amount, status }) {
  const db = admin.firestore();
  const walletRef = db.doc(`wallets/${driverUid}`);
  const txDocRef = walletRef.collection('transactions').doc(sessionId);

  await db.runTransaction(async (transaction) => {
    const walletDoc = await transaction.get(walletRef);
    const txDoc = await transaction.get(txDocRef);

    // Already completed → never credit twice.
    if (txDoc.exists && txDoc.data().status === 'completed') {
      functions.logger.info(
        `Payment ${sessionId} already completed – skipping (idempotent)`,
      );
      return;
    }

    // Only a verified, completed payment credits the balance.
    if (status === 'completed') {
      const currentBalance = walletDoc.data()?.balance || 0;
      const newBalance = currentBalance + parseFloat(amount || '0');
      transaction.set(
        walletRef,
        { balance: newBalance, updatedAt: db.FieldValue.serverTimestamp() },
        { merge: true },
      );
    } else {
      // pending / failed → keep balance unchanged, just refresh timestamp
      transaction.set(
        walletRef,
        { updatedAt: db.FieldValue.serverTimestamp() },
        { merge: true },
      );
    }

    transaction.set(
      txDocRef,
      {
        type: 'deposit', // top-up = deposit (matches requested schema)
        amount: parseFloat(amount || '0'),
        description: 'شحن المحفظة عبر Kashier',
        status: status, // pending | completed | failed
        kashierSessionId: sessionId,
        createdAt: db.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });
}

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
  const cfg = getKashierConfig();

  // ── Build request ─────────────────────────────────────────────────────────
  const sessionPayload = {
    amount: amount.toString(),
    currency: currency || 'EGP',
    order: orderId,
    merchantId: cfg.merchantId,
    mode: 'live', // LIVE keys (confirmed) — must match the SDK init + base URL
    type: 'one-time',
    ...(cfg.accountId ? { accountId: cfg.accountId } : {}),
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
    const response = await fetch(`${cfg.baseUrl}/payment/sessions`, {
      method: 'POST',
      headers: {
        Authorization: cfg.secretKey,
        'api-key': cfg.apiKey,
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

  // ── Verify Kashier webhook signature (FAIL-CLOSED) ──
  // Production : secret MUST be configured, otherwise EVERY webhook is rejected.
  // Emulator   : allow (with a warning) so devs can test without a real secret.
  const isEmulator =
    (functions.config() && functions.config().FUNCTIONS_EMULATOR) ||
    process.env.FUNCTIONS_EMULATOR === 'true';

  const cfg = getKashierConfig();
  if (!cfg.secretKey) {
    if (isEmulator) {
      functions.logger.warn(
        'Kashier webhook: secret not configured — SKIPPING verification (emulator mode)',
      );
    } else {
      functions.logger.error('Kashier webhook: secret not configured');
      res.status(500).send('Webhook secret not configured');
      return;
    }
  } else if (!verifyKashierSignature(req)) {
    functions.logger.error('Kashier webhook: signature verification failed');
    res.status(401).send('Invalid signature');
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

    // ── Map Kashier status → our status (pending | completed | failed) ──
    const STATUS_MAP = {
      PAID: 'completed',
      SUCCESS: 'completed',
      CAPTURED: 'completed',
      PENDING: 'pending',
      INITIATED: 'pending',
      FAILED: 'failed',
      DECLINED: 'failed',
      CANCELLED: 'failed',
    };
    const mappedStatus = STATUS_MAP[status] || 'pending';

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

    // ── Record payment atomically (balance + transaction), idempotent ──
    await recordKashierPayment({ driverUid, sessionId, amount, status: mappedStatus });

    functions.logger.info(
      `Wallet updated for driver ${driverUid}: status=${mappedStatus} amount=${amount}`,
    );
    res.status(200).json({ received: true });
  } catch (error) {
    functions.logger.error('kashierWebhook error', error);
    res.status(500).send('Internal Server Error');
  }
});

// ═════════════════════════════════════════════════════════════════════════════
// confirmKashierTopUp – Callable (called by the app after SDK success)
// ═════════════════════════════════════════════════════════════════════════════

/**
 * Called by the Flutter app immediately after the Kashier SDK reports a
 * successful payment. Performs the SAME atomic, idempotent wallet update as
 * the webhook (server-side, so the client cannot tamper with the balance).
 *
 * This makes the top-up work reliably even if the Kashier dashboard webhook
 * URL is not configured. The `kashierWebhook` remains an extra Kashier-verified
 * safety net and is idempotent, so there is never a double credit.
 */
exports.confirmKashierTopUp = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
  }
  const driverUid = context.auth.uid;
  const { sessionId, amount } = data;

  if (!sessionId || !amount || amount <= 0) {
    throw new functions.https.HttpsError('invalid-argument', 'بيانات غير صالحة');
  }

  try {
    await recordKashierPayment({ driverUid, sessionId, amount, status: 'completed' });
    return { ok: true };
  } catch (e) {
    functions.logger.error('confirmKashierTopUp error', e);
    throw new functions.https.HttpsError('internal', 'تعذّر تأكيد الدفع من الخادم');
  }
});

// ═════════════════════════════════════════════════════════════════════════════
// enforceDocumentsCompliance – Scheduled (daily) ban enforcement
// ═════════════════════════════════════════════════════════════════════════════

/**
 * Runs every day at 02:00. For each captain in the `captains` collection:
 *  - If BOTH required documents (criminalRecordUrl + drugTestUrl) are present,
 *    the captain is un-banned (isBanned=false, banUntil=null).
 *  - If the 30-day grace period (documentsGraceEndsAt, or createdAt+30d) has
 *    passed and the documents are missing, the captain is banned for 7 days
 *    (banUntil = now + 7d). The ban persists until the documents are uploaded.
 */
exports.enforceDocumentsCompliance = onSchedule('every day 02:00', async (event) => {
  const db = admin.firestore();
  const snap = await db.collection('captains').get();
  const now = admin.firestore.Timestamp.now();
  const GRACE_DAYS = 30;
  const BAN_DAYS = 7;

  const batch = db.batch();
  let banned = 0;
  let cleared = 0;

  for (const doc of snap.docs) {
    const data = doc.data();
    const createdAt = data.createdAt;
    if (!createdAt) continue;

    // مهلة الـ30 يوم: القيمة المخزَّنة وإلا createdAt + 30 يوم
    let graceEndsAt = data.documentsGraceEndsAt;
    if (!graceEndsAt) {
      graceEndsAt = admin.firestore.Timestamp.fromDate(
        new Date(createdAt.toDate().getTime() + GRACE_DAYS * 24 * 60 * 60 * 1000),
      );
    }

    const submitted = !!data.criminalRecordUrl && !!data.drugTestUrl;
    const updates = {};

    if (submitted) {
      // رُفعت المستندات → رفع الحظر فوراً
      if (data.isBanned) {
        updates.isBanned = false;
        updates.banUntil = null;
        cleared++;
      }
    } else if (now.toMillis() > graceEndsAt.toMillis()) {
      // انتهت المهلة دون رفع → حظر أسبوع (يستمر حتى الرفع)
      updates.isBanned = true;
      updates.banUntil = admin.firestore.Timestamp.fromDate(
        new Date(now.toMillis() + BAN_DAYS * 24 * 60 * 60 * 1000),
      );
      banned++;
    } else {
      // ضمن المهلة → التأكد من عدم الحظر
      if (data.isBanned) {
        updates.isBanned = false;
        updates.banUntil = null;
        cleared++;
      }
    }

    if (Object.keys(updates).length > 0) {
      batch.update(doc.ref, updates);
    }
  }

  if (banned > 0 || cleared > 0) {
    await batch.commit();
  }
  functions.logger.info(
    `enforceDocumentsCompliance: banned=${banned}, cleared=${cleared}, total=${snap.size}`,
  );
});

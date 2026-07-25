/**
 * Waslny Captain — Support Chat Routes
 *
 * Provides:
 *   GET  /api/v1/support/messages  — Load full conversation
 *   POST /api/v1/support/messages  — Send a new USER message
 *
 * All routes are protected by JWT (requireAuth).
 *
 * @see SupportChatRepository  (Flutter)
 * @see SupportMessage         (Flutter model)
 */

const express = require('express');
const prisma = require('../prisma');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

// ─────────────────────────────────────────────────────────────────────────
// GET / — Load the current user's full conversation
// ─────────────────────────────────────────────────────────────────────────
router.get('/', requireAuth, async (req, res) => {
  try {
    const messages = await prisma.message.findMany({
      where: { userId: req.user.userId },
      orderBy: { createdAt: 'asc' },
    });

    // Flutter expects: { data: { messages: [...] } }
    // But also supports direct { messages: [...] } payload.
    res.json({ data: { messages } });
  } catch (err) {
    console.error('[support] GET / error:', err);
    res.status(500).json({
      error: 'خطأ أثناء جلب الرسائل',
    });
  }
});

// ─────────────────────────────────────────────────────────────────────────
// POST / — Send a new USER message
// ─────────────────────────────────────────────────────────────────────────
router.post('/', requireAuth, async (req, res) => {
  try {
    const { text } = req.body;

    // Validate: text must be a non-empty string
    if (!text || typeof text !== 'string' || text.trim().length === 0) {
      return res.status(400).json({
        error: 'نص الرسالة مطلوب',
      });
    }

    const message = await prisma.message.create({
      data: {
        userId: req.user.userId,
        text: text.trim(),
        sender: 'USER',
      },
    });

    // Flutter expects: { data: { id, text, sender, createdAt } }
    res.status(201).json({ data: message });
  } catch (err) {
    console.error('[support] POST / error:', err);
    res.status(500).json({
      error: 'خطأ أثناء إرسال الرسالة',
    });
  }
});

module.exports = router;

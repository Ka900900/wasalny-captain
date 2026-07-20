const jwt = require('jsonwebtoken');
const config = require('../config');

/**
 * Express middleware that enforces a valid Bearer JWT.
 * Populates `req.user = { uid, phone, ... }` from the token payload.
 */
function requireAuth(req, res, next) {
  const header = req.headers['authorization'] || '';
  const [scheme, token] = header.split(' ');

  if (scheme !== 'Bearer' || !token) {
    return res.status(401).json({
      success: false,
      message: 'مطلوب تسجيل الدخول (Authorization Bearer Token مفقود)',
    });
  }

  try {
    const payload = jwt.verify(token, config.jwtSecret);
    req.user = payload;
    next();
  } catch (err) {
    return res.status(401).json({
      success: false,
      message: 'توكن غير صالح أو منتهٍ الصلاحية',
    });
  }
}

module.exports = { requireAuth };

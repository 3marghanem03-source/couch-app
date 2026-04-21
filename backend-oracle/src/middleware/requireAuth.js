const { verifyAccessToken } = require('../auth/jwt');

function requireAuth(req, res, next) {
  const h = req.headers.authorization || '';
  const parts = String(h).split(' ');
  const token = parts.length === 2 && parts[0].toLowerCase() === 'bearer' ? parts[1] : null;
  if (!token) return res.status(401).json({ error: 'Missing bearer token' });
  try {
    const claims = verifyAccessToken(token);
    req.user = claims;
    return next();
  } catch (e) {
    return res.status(401).json({ error: 'Invalid token' });
  }
}

module.exports = { requireAuth };


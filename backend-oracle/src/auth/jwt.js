const jwt = require('jsonwebtoken');

function requireEnv(name) {
  const v = process.env[name];
  if (!v) throw new Error(`Missing env ${name}`);
  return v;
}

function signAccessToken(payload) {
  const secret = requireEnv('JWT_SECRET');
  return jwt.sign(payload, secret, { expiresIn: '30d' });
}

function verifyAccessToken(token) {
  const secret = requireEnv('JWT_SECRET');
  return jwt.verify(token, secret);
}

module.exports = { signAccessToken, verifyAccessToken };


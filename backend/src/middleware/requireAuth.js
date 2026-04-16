const { admin, db } = require('../db/firestore');

async function requireAuth(req, res, next) {
  try {
    const header = req.headers.authorization || '';
    const [scheme, token] = header.split(' ');
    if (scheme !== 'Bearer' || !token) {
      return res.status(401).json({ error: 'Missing Authorization Bearer token' });
    }

    const decoded = await admin.auth().verifyIdToken(token);
    const uid = decoded.uid;

    // Role can be stored either in token custom claims or Firestore.
    const tokenRole =
      decoded.role ||
      decoded['role'] ||
      decoded.customClaims?.role ||
      undefined;

    let role = tokenRole;
    let profile = null;

    // Best-effort fetch profile; if Firestore isn't configured yet, still allow tokenRole.
    try {
      const userSnap = await db.collection('users').doc(uid).get();
      if (userSnap.exists) {
        profile = userSnap.data();
        role = role || profile.role;
      }
    } catch (_e) {
      // Ignore Firestore issues for auth verification itself.
    }

    if (!role) {
      return res.status(403).json({ error: 'User role not found' });
    }

    req.user = {
      uid,
      role,
      email: decoded.email,
      displayName: profile?.displayName || decoded.name || null,
    };

    return next();
  } catch (err) {
    return res.status(401).json({ error: 'Invalid/expired token' });
  }
}

module.exports = { requireAuth };


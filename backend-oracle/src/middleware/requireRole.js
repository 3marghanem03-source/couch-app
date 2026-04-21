function requireRole(role) {
  return function (req, res, next) {
    const r = req.user?.role;
    if (r !== role) return res.status(403).json({ error: 'Forbidden' });
    return next();
  };
}

module.exports = { requireRole };


function requireRole(...allowedRoles) {
  return (req, res, next) => {
    const role = req.user?.role;
    if (!role) return res.status(403).json({ error: 'Missing role' });
    if (!allowedRoles.includes(role)) {
      return res.status(403).json({ error: `Requires role: ${allowedRoles.join(', ')}` });
    }
    return next();
  };
}

module.exports = { requireRole };


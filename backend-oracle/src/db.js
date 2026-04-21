const oracledb = require('oracledb');

let _pool = null;

function requireEnv(name) {
  const v = process.env[name];
  if (!v) throw new Error(`Missing env ${name}`);
  return v;
}

async function initPool() {
  if (_pool) return _pool;
  _pool = await oracledb.createPool({
    user: requireEnv('ORACLE_USER'),
    password: requireEnv('ORACLE_PASSWORD'),
    connectString: requireEnv('ORACLE_CONNECT_STRING'),
    poolMin: 0,
    poolMax: 5,
    poolIncrement: 1,
  });
  return _pool;
}

async function withConn(fn) {
  await initPool();
  const conn = await _pool.getConnection();
  try {
    return await fn(conn);
  } finally {
    try {
      await conn.close();
    } catch (_) {}
  }
}

module.exports = { withConn, initPool };


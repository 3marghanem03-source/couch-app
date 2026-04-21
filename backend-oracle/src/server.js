const dotenv = require('dotenv');
dotenv.config();

const { createApp } = require('./app');
const { initPool } = require('./db');

const PORT = Number(process.env.PORT || 4010);

async function main() {
  await initPool();
  const app = createApp();
  app.listen(PORT, () => {
    // eslint-disable-next-line no-console
    console.log(`Oracle backend listening on http://localhost:${PORT}`);
  });
}

main().catch((e) => {
  // eslint-disable-next-line no-console
  console.error(e);
  process.exit(1);
});


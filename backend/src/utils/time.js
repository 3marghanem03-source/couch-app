const TIME_RE = /^([01]\d|2[0-3]):([0-5]\d)$/;

function assertValidHHmm(value, { name = 'time' } = {}) {
  if (!TIME_RE.test(value)) {
    throw new Error(`Invalid ${name}. Expected HH:mm (24h).`);
  }
}

function hhmmToMinutes(hhmm) {
  assertValidHHmm(hhmm, { name: 'HH:mm' });
  const [h, m] = hhmm.split(':').map((x) => Number(x));
  return h * 60 + m;
}

function assertEndAfterStart(start, end, { name = 'slot' } = {}) {
  const startMins = hhmmToMinutes(start);
  const endMins = hhmmToMinutes(end);
  if (endMins <= startMins) {
    throw new Error(`Invalid ${name}: end must be after start.`);
  }
}

module.exports = { assertValidHHmm, hhmmToMinutes, assertEndAfterStart };


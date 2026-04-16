const ISO_DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

function assertValidISODateString(dateStr, { name = 'date' } = {}) {
  if (!ISO_DATE_RE.test(dateStr)) {
    throw new Error(`Invalid ${name}. Expected YYYY-MM-DD.`);
  }
}

function addDaysISO(isoDateStr, daysToAdd) {
  // Parse as local date to keep the MVP simple and consistent with the stored date strings.
  const [y, m, d] = isoDateStr.split('-').map((x) => Number(x));
  const dt = new Date(y, m - 1, d);
  dt.setDate(dt.getDate() + daysToAdd);
  const yyyy = dt.getFullYear();
  const mm = String(dt.getMonth() + 1).padStart(2, '0');
  const dd = String(dt.getDate()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
}

function getWeekDateStrings(weekStartISO) {
  assertValidISODateString(weekStartISO, { name: 'weekStart' });
  return Array.from({ length: 7 }, (_v, i) => addDaysISO(weekStartISO, i));
}

module.exports = { getWeekDateStrings, assertValidISODateString };


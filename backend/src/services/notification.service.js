const { db } = require('../db/firestore');

async function notifyClientBookingApproved({ clientId, booking }) {
  // MVP: console/mock first. Later we can integrate SMS/WhatsApp/push.
  const clientSnap = await db.collection('users').doc(clientId).get();
  const client = clientSnap.exists ? clientSnap.data() : { uid: clientId };

  // eslint-disable-next-line no-console
  console.log(
    `[Notification] Booking approved. clientId=${clientId} coachId=${booking.coachId} bookingId=${booking.bookingId}`
  );
  // eslint-disable-next-line no-console
  console.log(`Client: ${client.email || client.displayName || clientId}`);
}

module.exports = { notifyClientBookingApproved };


const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { FieldPath, Timestamp, getFirestore } = require('firebase-admin/firestore');

initializeApp({
  credential: applicationDefault(),
  projectId: process.env.GCLOUD_PROJECT || 'stres-card',
});

const db = getFirestore();

async function commitUpdates(collectionName, updates) {
  for (let offset = 0; offset < updates.length; offset += 450) {
    const batch = db.batch();
    for (const update of updates.slice(offset, offset + 450)) {
      batch.update(db.collection(collectionName).doc(update.id), update.data);
    }
    await batch.commit();
  }
}

async function main() {
  const now = Date.now();
  const rooms = await db.collection('rooms').get();
  const roomUpdates = [];

  for (const doc of rooms.docs) {
    const data = doc.data();
    const status = data.roomStatus;
    let expiresAt;

    if (status === 'waiting') {
      const createdAt = data.createdAt;
      const base = createdAt instanceof Timestamp ? createdAt.toMillis() : now;
      expiresAt = Timestamp.fromMillis(base + 5 * 60 * 1000);
    } else if (status === 'cancelled' || status === 'finished') {
      expiresAt = Timestamp.fromMillis(now + 24 * 60 * 60 * 1000);
    } else {
      // Occupied and active rooms must never inherit an old waiting-room TTL.
      expiresAt = null;
    }

    const current = data.expiresAt;
    const same = (current === null && expiresAt === null) ||
      (current instanceof Timestamp && expiresAt instanceof Timestamp &&
       current.toMillis() === expiresAt.toMillis());
    if (!same) roomUpdates.push({ id: doc.id, data: { expiresAt } });
  }

  await commitUpdates('rooms', roomUpdates);

  const invites = await db.collection('invites').get();
  const inviteUpdates = [];
  for (const doc of invites.docs) {
    const data = doc.data();
    const createdAt = data.createdAt;
    if (data.status !== 'pending' || !(createdAt instanceof Timestamp)) continue;
    const expiresAt = Timestamp.fromMillis(createdAt.toMillis() + 5 * 60 * 1000);
    if (!(data.expiresAt instanceof Timestamp) ||
        data.expiresAt.toMillis() !== expiresAt.toMillis()) {
      inviteUpdates.push({ id: doc.id, data: { expiresAt } });
    }
  }
  await commitUpdates('invites', inviteUpdates);

  console.log(`Expiry backfill complete: ${roomUpdates.length} rooms, ${inviteUpdates.length} invites.`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

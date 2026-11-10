const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { FieldValue, Timestamp, getFirestore } = require('firebase-admin/firestore');

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
  // Move legacy invite codes out of publicly readable channel documents.
  // New channel documents keep the secret only under private/invite.
  const channels = await db.collection('channels').get();
  const legacyChannels = channels.docs.filter((doc) =>
    doc.data().visibility === 'invite_only' &&
    typeof doc.data().inviteCode === 'string' &&
    doc.data().inviteCode.length > 0,
  );
  for (let offset = 0; offset < legacyChannels.length; offset += 200) {
    const batch = db.batch();
    for (const doc of legacyChannels.slice(offset, offset + 200)) {
      batch.set(doc.ref.collection('private').doc('invite'), {
        inviteCode: doc.data().inviteCode,
      }, { merge: true });
      batch.update(doc.ref, { inviteCode: FieldValue.delete() });
    }
    await batch.commit();
  }

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
    } else if (status === 'finished') {
      const retentionDays = typeof data.tournamentMatchId === 'string' ? 30 : 1;
      expiresAt = Timestamp.fromMillis(now + retentionDays * 24 * 60 * 60 * 1000);
    } else if (status === 'cancelled') {
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

  const messages = await db.collectionGroup('room_messages').get();
  const messageUpdates = [];
  for (const doc of messages.docs) {
    const data = doc.data();
    if (data.expiresAt instanceof Timestamp) continue;
    const sentAt = data.sentAt;
    const base = sentAt instanceof Timestamp ? sentAt.toMillis() : now;
    messageUpdates.push({
      id: doc.ref.path,
      data: { expiresAt: Timestamp.fromMillis(base + 7 * 24 * 60 * 60 * 1000) },
    });
  }
  for (let offset = 0; offset < messageUpdates.length; offset += 450) {
    const batch = db.batch();
    for (const update of messageUpdates.slice(offset, offset + 450)) {
      batch.update(db.doc(update.id), update.data);
    }
    await batch.commit();
  }

  console.log(`Backfill complete: ${legacyChannels.length} legacy channel secrets migrated, ${roomUpdates.length} rooms, ${inviteUpdates.length} invites, ${messageUpdates.length} room messages.`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

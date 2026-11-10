const { readFileSync } = require('node:fs');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const {
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  where,
  writeBatch,
  serverTimestamp,
  increment,
  setDoc,
  updateDoc,
  arrayUnion,
} = require('firebase/firestore');
const { before, after, beforeEach, test } = require('node:test');

const projectId = 'demo-stres-card';
let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId,
    firestore: { rules: readFileSync('store/firestore.rules', 'utf8') },
  });
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
});

async function createChannel({ id, ownerUid, visibility, inviteCode }) {
  const db = env.authenticatedContext(ownerUid).firestore();
  const batch = writeBatch(db);
  batch.set(doc(db, `channels/${id}`), {
    name: id,
    description: 'Rules test channel',
    ownerDeviceId: ownerUid,
    ownerDisplayName: 'Owner',
    memberCount: 1,
    status: 'open',
    visibility,
    ...(inviteCode ? { inviteCode } : {}),
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  batch.set(doc(db, `channels/${id}/members/${ownerUid}`), {
    deviceId: ownerUid,
    playerDeviceId: `device-${ownerUid}`,
    displayName: 'Owner',
    role: 'owner',
    joinedAt: serverTimestamp(),
  });
  if (inviteCode) {
    batch.set(doc(db, `channel_invites/${inviteCode}`), {
      channelId: id,
      createdAt: serverTimestamp(),
    });
  }
  await assertSucceeds(batch.commit());
}

test('unauthenticated clients cannot discover or read channels', async () => {
  await createChannel({ id: 'public-one', ownerUid: 'owner-a', visibility: 'public' });
  const db = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(db, 'channels/public-one')));
  await assertFails(getDocs(collection(db, 'channels')));
});

test('public channels are discoverable only through a public-filtered query', async () => {
  await createChannel({ id: 'public-one', ownerUid: 'owner-a', visibility: 'public' });
  await createChannel({ id: 'private-one', ownerUid: 'owner-a', visibility: 'invite_only', inviteCode: 'AB234567' });
  const db = env.authenticatedContext('player-b').firestore();
  const result = await assertSucceeds(getDocs(query(
    collection(db, 'channels'),
    where('visibility', '==', 'public'),
  )));
  if (result.docs.length !== 1 || result.docs[0].id !== 'public-one') {
    throw new Error('Public channel query returned unexpected documents.');
  }
  await assertFails(getDoc(doc(db, 'channels/private-one')));
  await assertFails(getDocs(collection(db, 'channels')));
});

test('private channel requires a valid invite code before membership and is hidden afterwards', async () => {
  await createChannel({ id: 'private-one', ownerUid: 'owner-a', visibility: 'invite_only', inviteCode: 'AB234567' });
  const playerDb = env.authenticatedContext('player-b').firestore();
  await assertFails(getDoc(doc(playerDb, 'channels/private-one')));
  await assertSucceeds(getDoc(doc(playerDb, 'channel_invites/AB234567')));
  await assertFails(getDocs(collection(playerDb, 'channel_invites')));

  const batch = writeBatch(playerDb);
  batch.set(doc(playerDb, 'channels/private-one/members/player-b'), {
    deviceId: 'player-b',
    playerDeviceId: 'device-player-b',
    displayName: 'Player B',
    role: 'member',
    inviteCode: 'WRONGCODE',
    joinedAt: serverTimestamp(),
  });
  batch.update(doc(playerDb, 'channels/private-one'), {
    memberCount: increment(1),
    updatedAt: serverTimestamp(),
  });
  await assertFails(batch.commit());

  const validBatch = writeBatch(playerDb);
  validBatch.set(doc(playerDb, 'channels/private-one/members/player-b'), {
    deviceId: 'player-b',
    playerDeviceId: 'device-player-b',
    displayName: 'Player B',
    role: 'member',
    inviteCode: 'AB234567',
    joinedAt: serverTimestamp(),
  });
  validBatch.update(doc(playerDb, 'channels/private-one'), {
    memberCount: increment(1),
    updatedAt: serverTimestamp(),
  });
  await assertSucceeds(validBatch.commit());
  await assertSucceeds(getDoc(doc(playerDb, 'channels/private-one')));
  await assertSucceeds(getDocs(collection(playerDb, 'channels/private-one/members')));
});

test('channel chat is member-only and only channel owner can post announcements', async () => {
  await createChannel({ id: 'public-one', ownerUid: 'owner-a', visibility: 'public' });
  const ownerDb = env.authenticatedContext('owner-a').firestore();
  const outsiderDb = env.authenticatedContext('outsider').firestore();
  const memberDb = env.authenticatedContext('member-b').firestore();

  await assertSucceeds(setDoc(doc(ownerDb, 'channels/public-one/messages/owner-message'), {
    senderUid: 'owner-a', senderName: 'Owner', text: 'Welcome',
    isAnnouncement: true, sentAt: serverTimestamp(),
  }));
  await assertFails(setDoc(doc(memberDb, 'channels/public-one/messages/fake-announcement'), {
    senderUid: 'member-b', senderName: 'Member', text: 'Fake',
    isAnnouncement: true, sentAt: serverTimestamp(),
  }));
  await assertFails(setDoc(doc(memberDb, 'channels/public-one/messages/normal-message'), {
    senderUid: 'member-b', senderName: 'Member', text: 'Hello',
    isAnnouncement: false, sentAt: serverTimestamp(),
  }));

  const join = writeBatch(memberDb);
  join.set(doc(memberDb, 'channels/public-one/members/member-b'), {
    deviceId: 'member-b', playerDeviceId: 'device-member-b',
    displayName: 'Member', role: 'member', joinedAt: serverTimestamp(),
  });
  join.update(doc(memberDb, 'channels/public-one'), {
    memberCount: increment(1), updatedAt: serverTimestamp(),
  });
  await assertSucceeds(join.commit());
  await assertSucceeds(setDoc(doc(memberDb, 'channels/public-one/messages/normal-message'), {
    senderUid: 'member-b', senderName: 'Member', text: 'Hello',
    isAnnouncement: false, sentAt: serverTimestamp(),
  }));
  await assertFails(getDoc(doc(outsiderDb, 'channels/public-one/messages/owner-message')));
});

test('private tournament data is member-only and members can only register themselves', async () => {
  await createChannel({ id: 'private-one', ownerUid: 'owner-a', visibility: 'invite_only', inviteCode: 'AB234567' });
  const ownerDb = env.authenticatedContext('owner-a').firestore();
  await assertSucceeds(setDoc(doc(ownerDb, 'channels/private-one/tournaments/t1'), {
    title: 'Test Cup',
    status: 'registration',
    creatorDeviceId: 'owner-a',
    maxPlayers: 8,
    participantIds: [],
    createdAt: serverTimestamp(),
  }));

  const outsiderDb = env.authenticatedContext('outsider').firestore();
  await assertFails(getDoc(doc(outsiderDb, 'channels/private-one/tournaments/t1')));

  const playerDb = env.authenticatedContext('player-b').firestore();
  const joinBatch = writeBatch(playerDb);
  joinBatch.set(doc(playerDb, 'channels/private-one/members/player-b'), {
    deviceId: 'player-b',
    playerDeviceId: 'device-player-b',
    displayName: 'Player B',
    role: 'member',
    inviteCode: 'AB234567',
    joinedAt: serverTimestamp(),
  });
  joinBatch.update(doc(playerDb, 'channels/private-one'), {
    memberCount: increment(1),
    updatedAt: serverTimestamp(),
  });
  await assertSucceeds(joinBatch.commit());

  await assertSucceeds(updateDoc(doc(playerDb, 'channels/private-one/tournaments/t1'), {
    participantIds: arrayUnion('player-b'),
  }));
  await assertSucceeds(updateDoc(doc(ownerDb, 'channels/private-one/tournaments/t1'), {
    participantIds: arrayUnion('owner-a'),
  }));
  await assertFails(updateDoc(doc(playerDb, 'channels/private-one/tournaments/t1'), {
    participantIds: arrayUnion('somebody-else'),
  }));
  await assertFails(updateDoc(doc(playerDb, 'channels/private-one/tournaments/t1'), {
    status: 'in_progress',
    startedAt: serverTimestamp(),
  }));

  const startBatch = writeBatch(ownerDb);
  startBatch.update(doc(ownerDb, 'channels/private-one/tournaments/t1'), {
    status: 'in_progress',
    startedAt: serverTimestamp(),
    currentRound: 1,
    matchCount: 1,
  });
  startBatch.set(doc(ownerDb, 'channels/private-one/tournaments/t1/matches/r1_m1'), {
    round: 1,
    matchIndex: 1,
    player1Uid: 'owner-a',
    player1Name: 'Owner',
    player2Uid: 'player-b',
    player2Name: 'Player B',
    winnerUid: null,
    status: 'ready',
    createdAt: serverTimestamp(),
  });
  await assertSucceeds(startBatch.commit());

  await assertFails(updateDoc(doc(playerDb, 'channels/private-one/tournaments/t1/matches/r1_m1'), {
    winnerUid: 'player-b',
    status: 'completed',
    resultAt: serverTimestamp(),
  }));
  await assertSucceeds(updateDoc(doc(ownerDb, 'channels/private-one/tournaments/t1/matches/r1_m1'), {
    winnerUid: 'player-b',
    status: 'completed',
    resultAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(outsiderDb, 'channels/private-one/tournaments/t1/matches/r1_m1'), {
    winnerUid: 'owner-a',
    status: 'completed',
    resultAt: serverTimestamp(),
  }));
});

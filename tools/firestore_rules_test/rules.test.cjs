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
  deleteField,
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
    batch.set(doc(db, `channels/${id}/private/invite`), {
      inviteCode,
      updatedAt: serverTimestamp(),
    });
    batch.set(doc(db, `channel_invites/${inviteCode}`), {
      channelId: id,
      ownerUid,
      createdAt: serverTimestamp(),
    });
  }
  await assertSucceeds(batch.commit());
}

test('account nicknames are globally unique and owned by one authenticated UID', async () => {
  const ownerDb = env.authenticatedContext('nickname-owner').firestore();
  const otherDb = env.authenticatedContext('nickname-other').firestore();
  await assertSucceeds(setDoc(doc(ownerDb, 'nicknames/refleksustasi'), {
    uid: 'nickname-owner',
    displayName: 'RefleksUstasi',
    updatedAt: serverTimestamp(),
  }));
  await assertFails(setDoc(doc(otherDb, 'nicknames/refleksustasi'), {
    uid: 'nickname-other',
    displayName: 'RefleksUstasi',
    updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(getDoc(doc(otherDb, 'nicknames/refleksustasi')));
  await assertFails(getDocs(collection(otherDb, 'nicknames')));
});

test('unauthenticated clients cannot discover or read channels', async () => {
  await createChannel({ id: 'public-one', ownerUid: 'owner-a', visibility: 'public' });
  const db = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(db, 'channels/public-one')));
  await assertFails(getDocs(collection(db, 'channels')));
});

test('public and invite-only channels are both discoverable without exposing invite codes', async () => {
  await createChannel({ id: 'public-one', ownerUid: 'owner-a', visibility: 'public' });
  await createChannel({ id: 'private-one', ownerUid: 'owner-a', visibility: 'invite_only', inviteCode: 'AB234567' });
  const db = env.authenticatedContext('player-b').firestore();
  const result = await assertSucceeds(getDocs(collection(db, 'channels')));
  if (result.docs.length !== 2) {
    throw new Error('Both public and invite-only channels should be discoverable.');
  }
  const privateDoc = await assertSucceeds(getDoc(doc(db, 'channels/private-one')));
  if ('inviteCode' in (privateDoc.data() || {})) {
    throw new Error('Private invite code must not be exposed in the public channel document.');
  }
  await assertFails(getDoc(doc(db, 'channels/private-one/private/invite')));
});

test('private channel requires a valid invite code before membership and is hidden afterwards', async () => {
  await createChannel({ id: 'private-one', ownerUid: 'owner-a', visibility: 'invite_only', inviteCode: 'AB234567' });
  const playerDb = env.authenticatedContext('player-b').firestore();
  await assertSucceeds(getDoc(doc(playerDb, 'channels/private-one')));
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

test('invite-only channel join requests require owner approval before membership', async () => {
  await createChannel({ id: 'request-channel', ownerUid: 'owner-a', visibility: 'invite_only', inviteCode: 'CD234567' });
  const playerDb = env.authenticatedContext('player-c').firestore();
  const requestRef = doc(playerDb, 'channels/request-channel/join_requests/player-c');
  await assertSucceeds(setDoc(requestRef, {
    uid: 'player-c',
    displayName: 'Player C',
    status: 'pending',
    requestedAt: serverTimestamp(),
  }));
  await assertFails(setDoc(requestRef, {
    uid: 'player-c',
    displayName: 'Player C',
    status: 'pending',
    requestedAt: serverTimestamp(),
  }));
  await assertFails(getDoc(doc(playerDb, 'channels/request-channel/members/player-c')));

  const ownerDb = env.authenticatedContext('owner-a').firestore();
  const approval = writeBatch(ownerDb);
  approval.set(doc(ownerDb, 'channels/request-channel/members/player-c'), {
    deviceId: 'player-c',
    playerDeviceId: '',
    displayName: 'Player C',
    role: 'member',
    joinedAt: serverTimestamp(),
  });
  approval.update(doc(ownerDb, 'channels/request-channel'), {
    memberCount: increment(1),
    lastApprovedUid: 'player-c',
    updatedAt: serverTimestamp(),
  });
  approval.delete(doc(ownerDb, 'channels/request-channel/join_requests/player-c'));
  await assertSucceeds(approval.commit());
  await assertSucceeds(getDoc(doc(playerDb, 'channels/request-channel/members/player-c')));
});

test('guest clients may check an exact nickname but cannot enumerate account names', async () => {
  const ownerDb = env.authenticatedContext('nickname-owner').firestore();
  await assertSucceeds(setDoc(doc(ownerDb, 'nicknames/takmaad'), {
    uid: 'nickname-owner',
    displayName: 'TakmaAd',
    updatedAt: serverTimestamp(),
  }));
  const guestDb = env.unauthenticatedContext().firestore();
  await assertSucceeds(getDoc(doc(guestDb, 'nicknames/takmaad')));
  await assertFails(getDocs(collection(guestDb, 'nicknames')));
});

test('private tournament data is member-only and members can only register themselves', async () => {
  await createChannel({ id: 'private-one', ownerUid: 'owner-a', visibility: 'invite_only', inviteCode: 'AB234567' });
  const ownerDb = env.authenticatedContext('owner-a').firestore();
  await assertSucceeds(setDoc(doc(ownerDb, 'channels/private-one/tournaments/t1'), {
    title: 'Test Cup',
    format: 'single_elimination',
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

  await assertSucceeds(setDoc(doc(ownerDb, 'rooms/TOUR1'), {
    hostDeviceId: 'owner-a',
    guestDeviceId: null,
    inviteToDeviceId: 'player-b',
    roomStatus: 'waiting',
    tournamentChannelId: 'private-one',
    tournamentId: 't1',
    tournamentMatchId: 'r1_m1',
  }));
  await assertFails(updateDoc(doc(playerDb, 'channels/private-one/tournaments/t1/matches/r1_m1'), {
    roomCode: 'TOUR1',
    roomCreatedBy: 'player-b',
    roomLinkedAt: serverTimestamp(),
  }));
  await assertSucceeds(updateDoc(doc(ownerDb, 'channels/private-one/tournaments/t1/matches/r1_m1'), {
    roomCode: 'TOUR1',
    roomCreatedBy: 'owner-a',
    roomLinkedAt: serverTimestamp(),
  }));

  await assertSucceeds(updateDoc(doc(ownerDb, 'rooms/TOUR1'), {
    roomStatus: 'cancelled',
  }));
  await assertFails(updateDoc(doc(playerDb, 'channels/private-one/tournaments/t1/matches/r1_m1'), {
    roomCode: deleteField(),
    roomCreatedBy: deleteField(),
    roomLinkedAt: deleteField(),
  }));
  await assertSucceeds(updateDoc(doc(ownerDb, 'channels/private-one/tournaments/t1/matches/r1_m1'), {
    roomCode: deleteField(),
    roomCreatedBy: deleteField(),
    roomLinkedAt: deleteField(),
  }));

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


test('channel tournament stats are updated only once from a completed tournament', async () => {
  await createChannel({ id: 'stats-channel', ownerUid: 'owner-a', visibility: 'public' });
  const ownerDb = env.authenticatedContext('owner-a').firestore();
  const tournament = doc(ownerDb, 'channels/stats-channel/tournaments/stats-cup');
  await assertSucceeds(setDoc(tournament, {
    title: 'Stats Cup',
    format: 'single_elimination',
    status: 'registration',
    creatorDeviceId: 'owner-a',
    maxPlayers: 8,
    participantIds: [],
    createdAt: serverTimestamp(),
  }));
  await assertSucceeds(updateDoc(tournament, {
    participantIds: arrayUnion('owner-a'),
  }));
  await assertSucceeds(updateDoc(tournament, {
    status: 'completed',
    placements: {'owner-a': {rank: 1, stars: 100}},
    winnerUid: 'owner-a',
    completedAt: serverTimestamp(),
  }));
  const stats = doc(ownerDb, 'channels/stats-channel/tournament_stats/owner-a');
  await assertSucceeds(setDoc(stats, {
    uid: 'owner-a',
    tournamentIds: ['stats-cup'],
    tournamentsPlayed: 1,
    championships: 1,
    secondPlaces: 0,
    thirdPlaces: 0,
    podiums: 1,
    starsEarned: 100,
    lastTournamentId: 'stats-cup',
    lastRank: 1,
    lastStars: 100,
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(stats, {
    tournamentIds: ['stats-cup', 'stats-cup'],
    tournamentsPlayed: 2,
    championships: 2,
    lastTournamentId: 'stats-cup',
    lastRank: 1,
    lastStars: 100,
    updatedAt: serverTimestamp(),
  }));
  const outsiderDb = env.authenticatedContext('outsider').firestore();
  await assertFails(getDoc(doc(outsiderDb, 'channels/stats-channel/tournament_stats/owner-a')));
});

test('tournament podium rewards can only be claimed once by the eligible member', async () => {
  await createChannel({ id: 'public-one', ownerUid: 'owner-a', visibility: 'public' });
  const ownerDb = env.authenticatedContext('owner-a').firestore();
  const tournament = doc(ownerDb, 'channels/public-one/tournaments/podium');
  await assertSucceeds(setDoc(tournament, {
    title: 'Podium Cup',
    format: 'single_elimination',
    status: 'registration',
    creatorDeviceId: 'owner-a',
    maxPlayers: 8,
    participantIds: [],
    prizeStars: {'1': 100, '2': 60, '3': 30},
    createdAt: serverTimestamp(),
  }));
  await assertSucceeds(updateDoc(tournament, { participantIds: arrayUnion('owner-a') }));
  await assertSucceeds(updateDoc(tournament, {
    status: 'completed',
    placements: {
      'owner-a': {rank: 1, stars: 100},
      'player-b': {rank: 2, stars: 60},
    },
    winnerUid: 'owner-a',
    completedAt: serverTimestamp(),
  }));

  await assertSucceeds(setDoc(doc(ownerDb, 'channels/public-one/tournaments/podium/reward_claims/owner-a'), {
    uid: 'owner-a', rank: 1, stars: 100, claimedAt: serverTimestamp(),
  }));
  await assertFails(setDoc(doc(ownerDb, 'channels/public-one/tournaments/podium/reward_claims/owner-a'), {
    uid: 'owner-a', rank: 1, stars: 100, claimedAt: serverTimestamp(),
  }));
  await assertFails(setDoc(doc(ownerDb, 'channels/public-one/tournaments/podium/reward_claims/owner-a-2'), {
    uid: 'owner-a-2', rank: 1, stars: 100, claimedAt: serverTimestamp(),
  }));
  const outsiderDb = env.authenticatedContext('outsider').firestore();
  await assertFails(setDoc(doc(outsiderDb, 'channels/public-one/tournaments/podium/reward_claims/outsider'), {
    uid: 'outsider', rank: 1, stars: 100, claimedAt: serverTimestamp(),
  }));
});

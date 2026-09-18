// Rules-unit-testing suite for firestore.rules — run inside the `firebase`
// container via `firebase emulators:exec`, which starts the emulator with
// our real firestore.rules already loaded (see firebase.json) before this
// suite connects to it. See issue #16.
import { before, after, test } from 'node:test';
import assert from 'node:assert/strict';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, deleteDoc, collection, getDocs, query, where, collectionGroup } from 'firebase/firestore';

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-bookmarked',
    firestore: { host: '127.0.0.1', port: 8080 },
  });

  // Seed fixture data with rules disabled — mirrors real writes the app
  // would have made (club create + owner membership, personal docs, etc).
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();

    await setDoc(doc(db, 'users/alice'), { name: 'Alice', avatarUrl: null, readingGoal: 40, genres: [] });
    await setDoc(doc(db, 'users/bob'), { name: 'Bob', avatarUrl: null, readingGoal: 40, genres: [] });
    await setDoc(doc(db, 'users/carol'), { name: 'Carol', avatarUrl: null, readingGoal: 40, genres: [] });
    await setDoc(doc(db, 'users/dave'), { name: 'Dave', avatarUrl: null, readingGoal: 40, genres: [] });

    // Alice's personal data — used to confirm nobody else can touch it.
    await setDoc(doc(db, 'users/alice/books/book1'), { title: 'Fixture Book', author: 'Someone' });
    await setDoc(doc(db, 'users/alice/bingoCards/2026'), { year: 2026 });
    await setDoc(doc(db, 'users/alice/bingoCards/2026/squares/0'), { position: 0, label: 'x', completed: false, locked: false });
    await setDoc(doc(db, 'users/alice/bracketPicks/2026/matches/m1'), { matchId: 'm1', bookId: 'book1' });
    await setDoc(doc(db, 'users/alice/monthlyFavorites/2026/months/1'), { month: 1, bookId: 'book1' });

    // club1: alice owns it, bob is a plain member. Used for read-gating and
    // the self-promotion / cross-member-write negative tests (none of those
    // mutate state, so club1 stays stable for every test that reads it).
    await setDoc(doc(db, 'clubs/club1'), { name: 'Club One', description: null, imageUrl: null, ownerId: 'alice' });
    await setDoc(doc(db, 'clubs/club1/memberships/alice'), {
      userId: 'alice', role: 'owner', status: 'active', invitedById: null,
    });
    await setDoc(doc(db, 'clubs/club1/memberships/bob'), {
      userId: 'bob', role: 'member', status: 'active', invitedById: 'alice',
    });
    await setDoc(doc(db, 'clubs/club1/books/book1'), {
      title: 'Current Pick', author: 'Someone', isCurrent: true, totalChapters: 20,
    });
    await setDoc(doc(db, 'clubs/club1/books/book1/progress/alice'), { currentChapter: 5, finished: false });
    await setDoc(doc(db, 'clubs/club1/books/book1/progress/bob'), { currentChapter: 2, finished: false });
    await setDoc(doc(db, 'clubs/club1/books/book1/notes/note1'), {
      chapter: 1, body: "Alice's note", userId: 'alice',
    });
    await setDoc(doc(db, 'clubs/club1/bingoTemplate/0'), { label: 'Square 0' });
    await setDoc(doc(db, 'clubs/club1/bingoTemplate/12'), { label: 'FREE SPACE' });
    await setDoc(doc(db, 'clubs/club1/memberBingo/alice'), { wonAt: null });
    await setDoc(doc(db, 'clubs/club1/memberBingo/alice/squares/0'), { position: 0, label: 'x', completed: false, locked: false });
    await setDoc(doc(db, 'clubs/club1/memberBingo/alice/squares/12'), { position: 12, label: 'FREE SPACE', completed: true, locked: true });

    // club2: alice owns it, dave is a plain member — kept separate from
    // club1 so the "owner promotes a member" positive test (which actually
    // mutates dave's role) can't affect club1's other fixtures/tests.
    await setDoc(doc(db, 'clubs/club2'), { name: 'Club Two', description: null, imageUrl: null, ownerId: 'alice' });
    await setDoc(doc(db, 'clubs/club2/memberships/alice'), {
      userId: 'alice', role: 'owner', status: 'active', invitedById: null,
    });
    await setDoc(doc(db, 'clubs/club2/memberships/dave'), {
      userId: 'dave', role: 'member', status: 'active', invitedById: 'alice',
    });
  });
});

after(async () => {
  await testEnv.cleanup();
});

function asAlice() { return testEnv.authenticatedContext('alice').firestore(); }
function asBob() { return testEnv.authenticatedContext('bob').firestore(); }
function asCarol() { return testEnv.authenticatedContext('carol').firestore(); }
function asDave() { return testEnv.authenticatedContext('dave').firestore(); }
function asAnon() { return testEnv.unauthenticatedContext().firestore(); }

// --- The three cases issue #16 names explicitly ---------------------------

test('a non-member cannot read a club', async () => {
  await assertFails(getDoc(doc(asCarol(), 'clubs/club1')));
});

test('a member cannot promote themselves to owner', async () => {
  await assertFails(updateDoc(doc(asBob(), 'clubs/club1/memberships/bob'), { role: 'owner' }));
});

test('a user cannot write another user\'s books', async () => {
  await assertFails(setDoc(doc(asBob(), 'users/alice/books/hijack'), { title: 'nope', author: 'bob' }));
});

// --- Sanity: the legitimate versions of the above should succeed ----------

test('an active member can read their own club', async () => {
  await assertSucceeds(getDoc(doc(asBob(), 'clubs/club1')));
});

test('the owner can promote a member to admin (club2, isolated fixture)', async () => {
  await assertSucceeds(updateDoc(doc(asAlice(), 'clubs/club2/memberships/dave'), { role: 'admin' }));
  const after = await getDoc(doc(asAlice(), 'clubs/club2/memberships/dave'));
  assert.equal(after.data().role, 'admin');
});

test('a user can write their own books', async () => {
  await assertSucceeds(setDoc(doc(asAlice(), 'users/alice/books/book2'), { title: 'Mine', author: 'Alice' }));
});

// --- One negative case per remaining collection group ----------------------

test('users: a user cannot write another user\'s profile', async () => {
  await assertFails(updateDoc(doc(asBob(), 'users/alice'), { name: 'Hacked' }));
});

test('personal bingo: a user cannot write another user\'s bingo squares', async () => {
  await assertFails(updateDoc(doc(asBob(), 'users/alice/bingoCards/2026/squares/0'), { completed: true }));
});

test('bracket: a user cannot write another user\'s bracket picks', async () => {
  await assertFails(setDoc(doc(asBob(), 'users/alice/bracketPicks/2026/matches/m2'), { matchId: 'm2', bookId: 'book1' }));
});

test('monthly favorites: a user cannot write another user\'s favorites', async () => {
  await assertFails(setDoc(doc(asBob(), 'users/alice/monthlyFavorites/2026/months/2'), { month: 2, bookId: 'book1' }));
});

test('club books: a plain member cannot set the club\'s current book', async () => {
  await assertFails(setDoc(doc(asBob(), 'clubs/club1/books/book2'), {
    title: 'Sneaky Pick', author: 'Bob', isCurrent: true,
  }));
});

test('club books: the owner/admin can set the club\'s current book', async () => {
  await assertSucceeds(setDoc(doc(asAlice(), 'clubs/club1/books/book2'), {
    title: 'New Pick', author: 'Someone', isCurrent: true, totalChapters: 10,
  }));
});

test('club progress: a member cannot overwrite another member\'s real progress', async () => {
  await assertFails(updateDoc(doc(asBob(), 'clubs/club1/books/book1/progress/alice'), { currentChapter: 99 }));
});

test('club progress: a member can update their own progress', async () => {
  await assertSucceeds(updateDoc(doc(asBob(), 'clubs/club1/books/book1/progress/bob'), { currentChapter: 3 }));
});

test('club notes: a non-member cannot read notes', async () => {
  await assertFails(getDocs(collection(asCarol(), 'clubs/club1/books/book1/notes')));
});

test('club notes: a member cannot post a note under someone else\'s name', async () => {
  await assertFails(setDoc(doc(asBob(), 'clubs/club1/books/book1/notes/fake'), {
    chapter: 1, body: 'spoofed', userId: 'alice',
  }));
});

test('club notes: a member can post their own note', async () => {
  await assertSucceeds(setDoc(doc(asBob(), 'clubs/club1/books/book1/notes/bobs-note'), {
    chapter: 1, body: 'real note', userId: 'bob',
  }));
});

test('club bingo template: a plain member cannot write the template', async () => {
  await assertFails(setDoc(doc(asBob(), 'clubs/club1/bingoTemplate/0'), { label: 'Hacked' }));
});

test('club bingo template: owner/admin can write the template', async () => {
  await assertSucceeds(setDoc(doc(asAlice(), 'clubs/club1/bingoTemplate/1'), { label: 'Updated' }));
});

test('club bingo squares: a member cannot toggle another member\'s square', async () => {
  await assertFails(updateDoc(doc(asBob(), 'clubs/club1/memberBingo/alice/squares/0'), { completed: true }));
});

test('club bingo squares: a member cannot toggle their own locked free space', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'clubs/club1/memberBingo/bob/squares/12'), {
      position: 12, label: 'FREE SPACE', completed: true, locked: true,
    });
  });
  await assertFails(updateDoc(doc(asBob(), 'clubs/club1/memberBingo/bob/squares/12'), { completed: false }));
});

test('club bingo squares: a member can toggle their own unlocked square', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'clubs/club1/memberBingo/bob/squares/1'), {
      position: 1, label: 'Something', completed: false, locked: false,
    });
  });
  await assertSucceeds(updateDoc(doc(asBob(), 'clubs/club1/memberBingo/bob/squares/1'), { completed: true }));
});

// --- collectionGroup('memberships') query scoping --------------------------

test('collection group: a user only gets back their own membership rows', async () => {
  const snap = await getDocs(query(collectionGroup(asBob(), 'memberships'), where('userId', '==', 'bob')));
  assert.ok(snap.docs.length >= 1);
  for (const d of snap.docs) assert.equal(d.data().userId, 'bob');
});

test('collection group: a user cannot query another user\'s membership rows', async () => {
  await assertFails(getDocs(query(collectionGroup(asBob(), 'memberships'), where('userId', '==', 'alice'))));
});

// --- Unauthenticated access -------------------------------------------------

test('an unauthenticated request cannot read anything', async () => {
  await assertFails(getDoc(doc(asAnon(), 'clubs/club1')));
});

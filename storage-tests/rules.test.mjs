// Rules-unit-testing suite for storage.rules — run inside the `firebase`
// container via `firebase emulators:exec`, which starts the emulator with
// our real storage.rules (and firestore.rules, since storage.rules calls
// firestore.get()) already loaded before this suite connects. See issue #19.
import { before, after, test } from 'node:test';
import assert from 'node:assert/strict';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { doc, setDoc } from 'firebase/firestore';
import { ref, uploadBytes, getBytes } from 'firebase/storage';

let testEnv;

const smallImage = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3, 4]);
const oversizedImage = new Uint8Array(6 * 1024 * 1024);

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-bookmarked',
    firestore: { host: '127.0.0.1', port: 8080 },
    storage: { host: '127.0.0.1', port: 9199 },
  });

  // Seed the Firestore fixtures storage.rules' firestore.get() reads —
  // mirrors what firestore-tests/rules.test.mjs seeds for club1.
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'clubs/club1'), { name: 'Club One', ownerId: 'alice' });
    await setDoc(doc(db, 'clubs/club1/memberships/alice'), { userId: 'alice', role: 'owner', status: 'active' });
    await setDoc(doc(db, 'clubs/club1/memberships/bob'), { userId: 'bob', role: 'member', status: 'active' });
  });
});

after(async () => {
  await testEnv.cleanup();
});

test('a user can upload their own avatar', async () => {
  const storage = testEnv.authenticatedContext('alice').storage();
  await assertSucceeds(uploadBytes(ref(storage, 'avatars/alice'), smallImage, { contentType: 'image/jpeg' }));
});

test('a user cannot upload to another user\'s avatar path', async () => {
  const storage = testEnv.authenticatedContext('bob').storage();
  await assertFails(uploadBytes(ref(storage, 'avatars/alice'), smallImage, { contentType: 'image/jpeg' }));
});

test('an unauthenticated request cannot upload an avatar', async () => {
  const storage = testEnv.unauthenticatedContext().storage();
  await assertFails(uploadBytes(ref(storage, 'avatars/alice'), smallImage, { contentType: 'image/jpeg' }));
});

test('an oversized avatar is rejected', async () => {
  const storage = testEnv.authenticatedContext('alice').storage();
  await assertFails(uploadBytes(ref(storage, 'avatars/alice'), oversizedImage, { contentType: 'image/jpeg' }));
});

test('a non-image content type is rejected', async () => {
  const storage = testEnv.authenticatedContext('alice').storage();
  await assertFails(uploadBytes(ref(storage, 'avatars/alice'), smallImage, { contentType: 'application/pdf' }));
});

test('a signed-in user can read any avatar', async () => {
  const storage = testEnv.authenticatedContext('bob').storage();
  const bytes = await assertSucceeds(getBytes(ref(storage, 'avatars/alice')));
  assert.equal(bytes.byteLength, smallImage.length);
});

test('the club owner can upload the club image', async () => {
  const storage = testEnv.authenticatedContext('alice').storage();
  await assertSucceeds(uploadBytes(ref(storage, 'clubImages/club1'), smallImage, { contentType: 'image/png' }));
});

test('a plain member cannot upload the club image', async () => {
  const storage = testEnv.authenticatedContext('bob').storage();
  await assertFails(uploadBytes(ref(storage, 'clubImages/club1'), smallImage, { contentType: 'image/png' }));
});

test('a non-member cannot upload the club image', async () => {
  const storage = testEnv.authenticatedContext('carol').storage();
  await assertFails(uploadBytes(ref(storage, 'clubImages/club1'), smallImage, { contentType: 'image/png' }));
});

// Emulator-based security tests for ../firestore.rules
//
// Run with:
//   firebase emulators:exec --project demo-fintab --only firestore \
//     "node firestore-rules-test/rules.test.js"
//
// Each test asserts a write/read either SUCCEEDS (legit flow) or FAILS
// (attack / denied). Scenarios mirror the adversarial review of the 3
// critical fixes (masterUserId escalation, subscription forging, deletion).

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc,
  setDoc,
  getDoc,
  updateDoc,
  deleteDoc,
  writeBatch,
  serverTimestamp,
  Timestamp,
  deleteField,
} from 'firebase/firestore';

const __dirname = dirname(fileURLToPath(import.meta.url));
const RULES = readFileSync(join(__dirname, '..', 'firestore.rules'), 'utf8');

const A = 'master_A';
const C = 'collab_C';
const D = 'stranger_D';
const A_EMAIL = 'master@example.com';
const C_EMAIL = 'collab@example.com';
const INV = 'inv_AC';

const days = (n) => Timestamp.fromMillis(Date.now() + n * 86400 * 1000);

let env;
let passed = 0;
let failed = 0;
const failures = [];

async function test(name, fn) {
  try {
    await fn();
    passed++;
    console.log(`  ✅ ${name}`);
  } catch (e) {
    failed++;
    failures.push({ name, error: e.message });
    console.log(`  ❌ ${name}\n       ${e.message}`);
  }
}

// Auth context helpers (token carries email so callerEmail() works).
const asA = () => env.authenticatedContext(A, { email: A_EMAIL }).firestore();
const asC = () => env.authenticatedContext(C, { email: C_EMAIL }).firestore();
// Stranger D shares C's email-less identity; give D a distinct email.
const asD = () => env.authenticatedContext(D, { email: 'd@example.com' }).firestore();
// Mixed-case email to prove callerEmail().lower() normalisation.
const asCUpper = () =>
  env.authenticatedContext(C, { email: 'Collab@Example.com' }).firestore();

// Seed baseline data with rules DISABLED (simulates prior legit state).
async function seed() {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users', A), { userId: A, email: A_EMAIL });
    await setDoc(doc(db, 'users', C), { userId: C, email: C_EMAIL });
    await setDoc(doc(db, 'users', D), { userId: D, email: 'd@example.com' });
    await setDoc(doc(db, 'transactions', 'tx_A1'), {
      userId: A,
      title: 'A salary',
      amount: 100,
    });
    await setDoc(doc(db, 'invitations', INV), {
      id: INV,
      masterUserId: A,
      masterEmail: A_EMAIL,
      masterName: 'A',
      inviteeEmail: C_EMAIL,
      status: 'pending',
      createdAt: serverTimestamp(),
    });
  });
}

// Promote C to an accepted collaborator of A (rules DISABLED), used by tests
// that need the post-accept state without re-running the batch each time.
async function makeCcollaborator() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await updateDoc(doc(db, 'invitations', INV), {
      status: 'accepted',
      collaboratorUserId: C,
    });
    await setDoc(
      doc(db, 'users', C),
      { userId: C, email: C_EMAIL, masterUserId: A, masterInvitationId: INV },
      { merge: true },
    );
  });
}

async function main() {
  env = await initializeTestEnvironment({
    projectId: 'demo-fintab',
    firestore: { rules: RULES, host: '127.0.0.1', port: 8080 },
  });

  console.log('\n── masterUserId / privilege escalation ──');

  await seed();
  await test('ATTACK: stranger sets masterUserId=A on own profile without invite → denied', async () => {
    await assertFails(
      updateDoc(doc(asD(), 'users', D), { masterUserId: A }),
    );
  });

  await seed();
  await test('ATTACK: create own profile with masterUserId=A directly → denied', async () => {
    // fresh uid with no existing profile
    const E = 'fresh_E';
    const dbE = env.authenticatedContext(E, { email: 'e@example.com' }).firestore();
    await assertFails(
      setDoc(doc(dbE, 'users', E), { userId: E, masterUserId: A }),
    );
  });

  await seed();
  await test('ATTACK: stranger creates invitation with masterUserId=A (someone else) → denied', async () => {
    await assertFails(
      setDoc(doc(asD(), 'invitations', 'inv_fake'), {
        id: 'inv_fake',
        masterUserId: A,
        masterEmail: A_EMAIL,
        inviteeEmail: 'd@example.com',
        status: 'pending',
      }),
    );
  });

  await seed();
  await test('HAPPY: C accepts invite via batch (invitation→accepted + profile link) → allowed', async () => {
    const db = asC();
    const batch = writeBatch(db);
    batch.update(doc(db, 'invitations', INV), {
      status: 'accepted',
      collaboratorUserId: C,
    });
    batch.set(
      doc(db, 'users', C),
      { masterUserId: A, masterInvitationId: INV },
      { merge: true },
    );
    await assertSucceeds(batch.commit());
  });

  await seed();
  await test('ATTACK: C forges link with masterInvitationId pointing at someone-else’s invite → denied', async () => {
    // Invitation INV is addressed to C, but C tries to claim D as master with a
    // mismatched invitation (status still pending → invitationAuthorizesLink fails).
    await assertFails(
      setDoc(
        doc(asC(), 'users', C),
        { masterUserId: D, masterInvitationId: INV },
        { merge: true },
      ),
    );
  });

  await seed();
  await makeCcollaborator();
  await test('HAPPY: collaborator C reads master A’s transaction → allowed', async () => {
    await assertSucceeds(getDoc(doc(asC(), 'transactions', 'tx_A1')));
  });

  await seed();
  await makeCcollaborator();
  await test('ATTACK: stranger D reads master A’s transaction → denied', async () => {
    await assertFails(getDoc(doc(asD(), 'transactions', 'tx_A1')));
  });

  await seed();
  await makeCcollaborator();
  await test('HAPPY: collaborator C updates own displayName (masterUserId untouched) → allowed', async () => {
    await assertSucceeds(
      updateDoc(doc(asC(), 'users', C), { displayName: 'Carlos' }),
    );
  });

  await seed();
  await makeCcollaborator();
  await test('HAPPY: C leaves shared account (removes masterUserId + masterInvitationId) → allowed', async () => {
    await assertSucceeds(
      updateDoc(doc(asC(), 'users', C), {
        masterUserId: deleteField(),
        masterInvitationId: deleteField(),
      }),
    );
  });

  await seed();
  await makeCcollaborator();
  await test('HAPPY: master A detaches collaborator C (removes link fields on C’s doc) → allowed', async () => {
    await assertSucceeds(
      updateDoc(doc(asA(), 'users', C), {
        masterUserId: deleteField(),
        masterInvitationId: deleteField(),
      }),
    );
  });

  await seed();
  await makeCcollaborator();
  await test('ATTACK: collaborator C re-points own masterUserId to D while linked → denied', async () => {
    await assertFails(
      updateDoc(doc(asC(), 'users', C), { masterUserId: D }),
    );
  });

  await seed();
  await test('ATTACK: invitee C mutates inviteeEmail on the invitation → denied', async () => {
    await assertFails(
      updateDoc(doc(asC(), 'invitations', INV), { inviteeEmail: 'd@example.com' }),
    );
  });

  await seed();
  await makeCcollaborator();
  await test('HAPPY (B2): C declines own accepted invite on self-deletion → allowed', async () => {
    await assertSucceeds(
      updateDoc(doc(asC(), 'invitations', INV), { status: 'declined' }),
    );
  });

  await seed();
  await makeCcollaborator();
  await test('ATTACK: collaborator C deletes the master’s invitation doc → denied', async () => {
    await assertFails(deleteDoc(doc(asC(), 'invitations', INV)));
  });

  await seed();
  await test('HAPPY: callerEmail().lower() — mixed-case token email still matches invite', async () => {
    // C authenticates with 'Collab@Example.com'; invite stored 'collab@example.com'.
    await assertSucceeds(
      updateDoc(doc(asCUpper(), 'invitations', INV), {
        status: 'accepted',
        collaboratorUserId: C,
      }),
    );
  });

  console.log('\n── subscription validation ──');

  await seed();
  await test('HAPPY: legit annual write (366d, server ts) → allowed', async () => {
    await assertSucceeds(
      setDoc(doc(asA(), 'subscriptions', A), {
        type: 'annual',
        status: 'active',
        purchaseToken: 'a-real-long-jws-receipt-token-value',
        productId: 'pro_annual',
        expiryDate: days(366),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  await seed();
  await test('HAPPY: empty purchaseToken on restore still allowed (B1 fix) → allowed', async () => {
    await assertSucceeds(
      setDoc(doc(asA(), 'subscriptions', A), {
        type: 'monthly',
        status: 'active',
        purchaseToken: '',
        productId: 'pro_monthly',
        expiryDate: days(32),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  await seed();
  await test('HAPPY: clearSubscription (status=expired, merge) → allowed', async () => {
    await assertSucceeds(
      setDoc(
        doc(asA(), 'subscriptions', A),
        { status: 'expired', updatedAt: serverTimestamp() },
        { merge: true },
      ),
    );
  });

  await seed();
  await test('ATTACK: perpetual Pro (expiryDate = now+10y) → denied', async () => {
    await assertFails(
      setDoc(doc(asA(), 'subscriptions', A), {
        type: 'annual',
        status: 'active',
        purchaseToken: 'x'.repeat(40),
        productId: 'pro_annual',
        expiryDate: days(3650),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  await seed();
  await test('ATTACK: junk extra field in subscription → denied', async () => {
    await assertFails(
      setDoc(doc(asA(), 'subscriptions', A), {
        type: 'annual',
        status: 'active',
        purchaseToken: 'x'.repeat(40),
        productId: 'pro_annual',
        expiryDate: days(366),
        updatedAt: serverTimestamp(),
        hacked: true,
      }),
    );
  });

  await seed();
  await test('ATTACK: unknown productId → denied', async () => {
    await assertFails(
      setDoc(doc(asA(), 'subscriptions', A), {
        type: 'annual',
        status: 'active',
        purchaseToken: 'x'.repeat(40),
        productId: 'pirate_lifetime',
        expiryDate: days(366),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  await seed();
  await test('ATTACK: client-set updatedAt (not server time) → denied', async () => {
    await assertFails(
      setDoc(doc(asA(), 'subscriptions', A), {
        type: 'annual',
        status: 'active',
        purchaseToken: 'x'.repeat(40),
        productId: 'pro_annual',
        expiryDate: days(366),
        updatedAt: Timestamp.fromMillis(Date.now() - 1000),
      }),
    );
  });

  await seed();
  await test('ATTACK: write to ANOTHER user’s subscription doc → denied', async () => {
    await assertFails(
      setDoc(doc(asD(), 'subscriptions', A), {
        type: 'annual',
        status: 'active',
        purchaseToken: 'x'.repeat(40),
        productId: 'pro_annual',
        expiryDate: days(366),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  await seed();
  await test('KNOWN RESIDUAL RISK: forged ~399d Pro with padded token is bounded-but-allowed', async () => {
    // Documents the accepted limitation: closing this needs server-side receipt
    // validation (Cloud Function). The rule only CAPS the damage to <400d.
    await assertSucceeds(
      setDoc(doc(asA(), 'subscriptions', A), {
        type: 'annual',
        status: 'active',
        purchaseToken: 'x'.repeat(21),
        productId: 'pro_annual',
        expiryDate: days(399),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  console.log('\n── account deletion (owner wipes own data) ──');

  await seed();
  await test('HAPPY: owner deletes own transaction → allowed', async () => {
    await assertSucceeds(deleteDoc(doc(asA(), 'transactions', 'tx_A1')));
  });

  await seed();
  await test('HAPPY: owner deletes own subscription + user doc → allowed', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'subscriptions', A), { status: 'expired' });
    });
    await assertSucceeds(deleteDoc(doc(asA(), 'subscriptions', A)));
    await assertSucceeds(deleteDoc(doc(asA(), 'users', A)));
  });

  await env.cleanup();

  console.log(`\n${'─'.repeat(48)}`);
  console.log(`RESULT: ${passed} passed, ${failed} failed`);
  if (failed > 0) {
    console.log('\nFAILURES:');
    for (const f of failures) console.log(`  • ${f.name}\n    ${f.error}`);
    process.exit(1);
  }
  console.log('All security rule tests passed ✅');
}

main().catch((e) => {
  console.error('FATAL', e);
  process.exit(2);
});

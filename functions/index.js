const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {logger} = require("firebase-functions");
const {initializeApp} = require("firebase-admin/app");
const {
  getFirestore,
  FieldValue,
  Timestamp,
} = require("firebase-admin/firestore");

initializeApp();
const db = getFirestore();

// How many days of Pro the referrer earns per accepted referral, and the
// yearly cap that stops someone farming free Pro with fake accounts.
const REWARD_DAYS = 30;
const MAX_REWARDS_PER_REFERRER = 12;
const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Grants the referrer 1 month of Pro when an invited user becomes ACTIVE
 * (creates their first transaction). Server-side and idempotent per invitee —
 * the only trustworthy place to hand out something worth money.
 *
 * Trigger: any new transaction. The function exits cheaply for the vast
 * majority of writes (users with no referrer / already processed).
 */
exports.grantReferralReward = onDocumentCreated(
    "transactions/{txId}",
    async (event) => {
      const tx = event.data && event.data.data();
      const inviteeId = tx && tx.userId;
      if (!inviteeId) return;

      const inviteeRef = db.collection("users").doc(inviteeId);
      // Ledger keyed by invitee → at most ONE reward per invited account ever,
      // regardless of any client-side field tampering.
      const ledgerRef = db.collection("referralRewards").doc(inviteeId);

      try {
        await db.runTransaction(async (t) => {
          // ---- All reads first (Firestore requires reads before writes) ----
          const inviteeSnap = await t.get(inviteeRef);
          if (!inviteeSnap.exists) return;
          const ledgerSnap = await t.get(ledgerRef);
          if (ledgerSnap.exists) return; // already processed this invitee

          const invitee = inviteeSnap.data();
          const referrerId = invitee.referredBy;
          if (!referrerId) return; // not referred
          if (referrerId === inviteeId) return; // self-referral guard

          const referrerRef = db.collection("users").doc(referrerId);
          // Cap counter lives in a function-only collection so a referrer can't
          // reset it from the client to bypass the cap.
          const statsRef = db.collection("referralStats").doc(referrerId);
          const subRef = db.collection("subscriptions").doc(referrerId);

          const [referrerSnap, statsSnap, subSnap] = await Promise.all([
            t.get(referrerRef),
            t.get(statsRef),
            t.get(subRef),
          ]);
          if (!referrerSnap.exists) return;

          const grantedCount =
            (statsSnap.exists && statsSnap.data().grantedCount) || 0;

          // ---- Writes ----
          // Mark the invitee processed so we don't re-run on every transaction.
          t.set(inviteeRef, {
            referralRewardGranted: true,
            referralRewardAt: FieldValue.serverTimestamp(),
          }, {merge: true});

          if (grantedCount >= MAX_REWARDS_PER_REFERRER) {
            t.set(ledgerRef, {
              referrerId,
              inviteeId,
              days: 0,
              capped: true,
              grantedAt: FieldValue.serverTimestamp(),
            });
            return;
          }

          // Extend the referrer's Pro by REWARD_DAYS, stacking on any existing
          // time (paid or previously gifted).
          const now = Date.now();
          let base = now;
          if (subSnap.exists) {
            const exp = subSnap.data().expiryDate;
            const expMs = exp instanceof Timestamp ?
              exp.toMillis() :
              (exp ? new Date(exp).getTime() : 0);
            if (expMs > now) base = expMs;
          }
          const newExpiry = Timestamp.fromMillis(base + REWARD_DAYS * DAY_MS);
          const prev = subSnap.exists ? subSnap.data() : {};

          t.set(subRef, {
            status: "active",
            type: prev.type || "monthly",
            productId: prev.productId || "referral_reward",
            purchaseToken: prev.purchaseToken || "",
            expiryDate: newExpiry,
            updatedAt: FieldValue.serverTimestamp(),
            lastReferralRewardAt: FieldValue.serverTimestamp(),
          }, {merge: true});

          t.set(statsRef, {
            grantedCount: grantedCount + 1,
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});

          t.set(ledgerRef, {
            referrerId,
            inviteeId,
            days: REWARD_DAYS,
            grantedAt: FieldValue.serverTimestamp(),
          });
        });
      } catch (err) {
        logger.error("grantReferralReward failed", {inviteeId, err});
      }
    },
);

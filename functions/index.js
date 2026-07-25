const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onRequest, onCall, HttpsError} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {logger} = require("firebase-functions");
const {initializeApp} = require("firebase-admin/app");
const {
  getFirestore,
  FieldValue,
  Timestamp,
} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();
const db = getFirestore();

// ── Workspace ("Carteira") sharing ───────────────────────────────────────────
// Accepting an invite adds the INVITEE to the workspace's membership with the
// role the OWNER assigned. This is the one privilege-sensitive mutation in the
// whole sharing model (a client could otherwise self-assign 'editor' or join a
// workspace it wasn't invited to), so it runs here with the Admin SDK. The
// Firestore rules deliberately freeze workspace membership for non-owners.
exports.acceptWorkspaceInvite = onCall(
    {region: "us-central1"},
    async (request) => {
      const uid = request.auth && request.auth.uid;
      const email = request.auth && request.auth.token &&
        (request.auth.token.email || "").toLowerCase();
      if (!uid || !email) {
        throw new HttpsError("unauthenticated", "Sign in required.");
      }
      const invitationId = request.data && request.data.invitationId;
      if (!invitationId || typeof invitationId !== "string") {
        throw new HttpsError("invalid-argument", "invitationId required.");
      }

      const invRef = db.collection("invitations").doc(invitationId);
      const invSnap = await invRef.get();
      if (!invSnap.exists) {
        throw new HttpsError("not-found", "Invitation not found.");
      }
      const inv = invSnap.data();
      if ((inv.inviteeEmail || "").toLowerCase() !== email) {
        throw new HttpsError("permission-denied", "Not your invitation.");
      }
      if (!inv.workspaceId) {
        throw new HttpsError("failed-precondition",
            "Legacy invitation — accept via the app's legacy flow.");
      }
      // Idempotent: re-accepting an already-accepted invitation is a no-op.
      if (inv.status === "accepted" && inv.collaboratorUserId === uid) {
        return {ok: true, workspaceId: inv.workspaceId};
      }
      if (inv.status !== "pending") {
        throw new HttpsError("failed-precondition",
            `Invitation is ${inv.status}.`);
      }
      const role = inv.role === "viewer" ? "viewer" : "editor";

      const wsRef = db.collection("workspaces").doc(inv.workspaceId);
      const wsSnap = await wsRef.get();
      if (!wsSnap.exists || wsSnap.data().ownerId !== inv.masterUserId) {
        throw new HttpsError("failed-precondition",
            "Workspace no longer exists.");
      }

      const batch = db.batch();
      batch.update(invRef, {
        status: "accepted",
        collaboratorUserId: uid,
        acceptedAt: FieldValue.serverTimestamp(),
      });
      batch.update(wsRef, {
        memberUids: FieldValue.arrayUnion(uid),
        [`roles.${uid}`]: role,
      });
      await batch.commit();
      logger.info("acceptWorkspaceInvite", {invitationId, uid, role});
      return {ok: true, workspaceId: inv.workspaceId};
    },
);

// A member (not the owner) removes THEMSELVES from a workspace. The owner
// revokes members client-side (owners may write their own workspace doc).
exports.leaveWorkspace = onCall(
    {region: "us-central1"},
    async (request) => {
      const uid = request.auth && request.auth.uid;
      if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");
      const workspaceId = request.data && request.data.workspaceId;
      if (!workspaceId || typeof workspaceId !== "string") {
        throw new HttpsError("invalid-argument", "workspaceId required.");
      }
      const wsRef = db.collection("workspaces").doc(workspaceId);
      const wsSnap = await wsRef.get();
      if (!wsSnap.exists) return {ok: true}; // already gone — idempotent
      const ws = wsSnap.data();
      if (ws.ownerId === uid) {
        throw new HttpsError("failed-precondition",
            "The owner cannot leave their own workspace.");
      }
      await wsRef.update({
        memberUids: FieldValue.arrayRemove(uid),
        [`roles.${uid}`]: FieldValue.delete(),
      });
      logger.info("leaveWorkspace", {workspaceId, uid});
      return {ok: true};
    },
);

// ── Market-data CORS proxy ───────────────────────────────────────────────────
// Browsers block direct calls to Yahoo Finance / CoinGecko (no CORS headers),
// so the web build routes quote/search/history requests through this function.
// Native apps call the upstreams directly and never hit this.
const ALLOWED_QUOTE_HOSTS = new Set([
  "query1.finance.yahoo.com",
  "query2.finance.yahoo.com",
  "api.coingecko.com",
]);

exports.quoteProxy = onRequest(
    {cors: true, region: "us-central1", memory: "128MiB", timeoutSeconds: 20},
    async (req, res) => {
      const target = req.query.url;
      if (!target || typeof target !== "string") {
        res.status(400).json({error: "missing url param"});
        return;
      }
      let host;
      try {
        host = new URL(target).host;
      } catch (e) {
        res.status(400).json({error: "invalid url"});
        return;
      }
      if (!ALLOWED_QUOTE_HOSTS.has(host)) {
        res.status(403).json({error: "host not allowed"});
        return;
      }
      try {
        const upstream = await fetch(target, {
          headers: {"User-Agent": "Mozilla/5.0 (Fintab)"},
        });
        const body = await upstream.text();
        res.set("Cache-Control", "public, max-age=60");
        res.status(upstream.status).type("application/json").send(body);
      } catch (err) {
        logger.error("quoteProxy failed", {target, err: String(err)});
        res.status(502).json({error: "upstream failed"});
      }
    },
);

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

// ── Price alerts (investimentos) ─────────────────────────────────────────────
// Every 15 min: fetch quotes for all active alerts and fire the ones whose
// target was crossed. Fires at most once per alert (transaction guards against
// the app-side on-open checker racing this job), flips the alert to inactive
// and pushes an FCM notification to every device of the alert's owner.
// Quote endpoints/formats mirror lib/features/investments/data/
// investment_quote_service.dart (Yahoo v8 chart meta + CoinGecko simple/price).

const QUOTE_HEADERS = {"User-Agent": "Mozilla/5.0 (Fintab)"};

/** pt-BR / en-US currency formatting, matching the app's fmtNative. Cheap
 * crypto (< 1 unit) keeps up to 8 decimals so targets don't render as 0,00. */
function fmtAlertMoney(v, currency, crypto) {
  const maxDigits = crypto && Math.abs(v) < 1 ? 8 : 2;
  return new Intl.NumberFormat(currency === "USD" ? "en-US" : "pt-BR", {
    style: "currency",
    currency: currency === "USD" ? "USD" : "BRL",
    minimumFractionDigits: 2,
    maximumFractionDigits: maxDigits,
  }).format(v);
}

async function fetchStockPrice(symbol) {
  try {
    const url = "https://query1.finance.yahoo.com/v8/finance/chart/" +
        encodeURIComponent(symbol) + "?range=1d&interval=1d";
    const r = await fetch(url,
        {headers: QUOTE_HEADERS, signal: AbortSignal.timeout(8000)});
    if (!r.ok) return null;
    const j = await r.json();
    const p = j && j.chart && j.chart.result && j.chart.result[0] &&
        j.chart.result[0].meta && j.chart.result[0].meta.regularMarketPrice;
    return typeof p === "number" && isFinite(p) ? p : null;
  } catch (e) {
    logger.warn("priceAlertsCheck stock fetch failed", {symbol, e: String(e)});
    return null;
  }
}

async function fetchCryptoPrices(ids) {
  if (!ids.length) return {};
  try {
    const url = "https://api.coingecko.com/api/v3/simple/price?ids=" +
        encodeURIComponent(ids.join(",")) + "&vs_currencies=brl";
    const r = await fetch(url,
        {headers: QUOTE_HEADERS, signal: AbortSignal.timeout(8000)});
    if (!r.ok) return {};
    const j = await r.json();
    const out = {};
    for (const id of ids) {
      const p = j && j[id] && j[id].brl;
      if (typeof p === "number" && isFinite(p)) out[id] = p;
    }
    return out;
  } catch (e) {
    logger.warn("priceAlertsCheck crypto fetch failed", {e: String(e)});
    return {};
  }
}

exports.priceAlertsCheck = onSchedule(
    {
      schedule: "every 15 minutes",
      region: "us-central1",
      memory: "256MiB",
      timeoutSeconds: 120,
    },
    async () => {
      const snap = await db.collection("price_alerts")
          .where("active", "==", true).limit(500).get();
      if (snap.empty) return;

      // One fetch per unique symbol: crypto batched, stocks sequential (keeps
      // Yahoo happy; alert volume is small).
      const stockSyms = new Set();
      const cryptoIds = new Set();
      for (const d of snap.docs) {
        const a = d.data();
        if (!a.quoteSymbol) continue;
        if (a.kind === "crypto") cryptoIds.add(a.quoteSymbol);
        else stockSyms.add(a.quoteSymbol);
      }
      const prices = await fetchCryptoPrices([...cryptoIds]);
      for (const sym of stockSyms) {
        const p = await fetchStockPrice(sym);
        if (p != null) prices[sym] = p;
      }

      let fired = 0;
      for (const doc of snap.docs) {
        const a = doc.data();
        const price = prices[a.quoteSymbol];
        const target = Number(a.targetPrice);
        if (price == null || !isFinite(price) || price <= 0 ||
            !isFinite(target) || target <= 0) continue;
        const hit = a.condition === "below" ? price <= target : price >= target;
        if (!hit) continue;

        // Delivery check BEFORE the claim: with no push tokens (e.g. iOS
        // while APNs isn't configured) the alert must stay active so the
        // app-side checker can still deliver it locally on next open.
        let tokDoc = null;
        let tokens = [];
        try {
          tokDoc = await db.collection("fcm_tokens").doc(a.userId).get();
          tokens = tokDoc.exists && Array.isArray(tokDoc.data().tokens) ?
              tokDoc.data().tokens.filter((t) => typeof t === "string") : [];
        } catch (err) {
          logger.error("priceAlertsCheck token read failed",
              {alertId: doc.id, err: String(err)});
        }
        if (!tokens.length) continue;

        // Claim the trigger atomically — loses gracefully to the app-side
        // checker or a previous run.
        const won = await db.runTransaction(async (t) => {
          const fresh = await t.get(doc.ref);
          if (!fresh.exists || fresh.data().active !== true) return false;
          t.update(doc.ref, {
            active: false,
            triggeredAt: FieldValue.serverTimestamp(),
            triggeredPrice: price,
          });
          return true;
        }).catch((err) => {
          logger.error("priceAlertsCheck claim failed",
              {alertId: doc.id, err: String(err)});
          return false;
        });
        if (!won) continue;

        try {
          const currency = a.kind === "stockUs" ? "USD" : "BRL";
          const isCrypto = a.kind === "crypto";
          const up = a.condition !== "below";
          const res = await getMessaging().sendEachForMulticast({
            tokens,
            notification: {
              title: (up ? "📈 " : "📉 ") + a.ticker + " atingiu " +
                  fmtAlertMoney(price, currency, isCrypto),
              body: "Seu alerta de " + (up ? "acima de " : "abaixo de ") +
                  fmtAlertMoney(target, currency, isCrypto) +
                  " disparou. Toque para ver.",
            },
            data: {type: "price_alert", alertId: doc.id},
            android: {notification: {channelId: "price_alerts"}},
            apns: {payload: {aps: {sound: "default"}}},
          });
          // Prune ONLY dead registration tokens — a payload-level
          // invalid-argument fails for every token and must not wipe the doc.
          const dead = [];
          res.responses.forEach((r, i) => {
            const code = r.error && r.error.code;
            if (code === "messaging/registration-token-not-registered" ||
                code === "messaging/invalid-registration-token") {
              dead.push(tokens[i]);
            }
          });
          if (dead.length) {
            await tokDoc.ref.update({tokens: FieldValue.arrayRemove(...dead)})
                .catch(() => {});
          }
          if (res.successCount === 0) {
            throw new Error("no push delivered (" +
                res.failureCount + " failures)");
          }
          fired++;
        } catch (err) {
          logger.error("priceAlertsCheck push failed",
              {alertId: doc.id, err: String(err)});
          // Undo the claim so the alert can still fire later (next scheduled
          // run after token pruning, or the app-side local checker).
          await doc.ref.update({
            active: true,
            triggeredAt: FieldValue.delete(),
            triggeredPrice: FieldValue.delete(),
          }).catch((e2) => logger.error("priceAlertsCheck revert failed",
              {alertId: doc.id, err: String(e2)}));
        }
      }
      logger.info("priceAlertsCheck done", {alerts: snap.size, fired});
    },
);

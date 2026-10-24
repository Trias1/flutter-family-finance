import { FieldValue, type DocumentReference, type Firestore } from "firebase-admin/firestore"
import { NextRequest, NextResponse } from "next/server"

import { auth, db, errorResponse, HttpError, rateLimit, readJson, requireUser } from "@/lib/api-auth"

export const runtime = "nodejs"

// Collections whose documents are scoped by `familyId` (a family id, or the
// user's uid for personal records). Matches lib/core/constants on Android.
const FINANCE = [
  "incomes",
  "expenses",
  "savings",
  "budgets",
  "debts",
  "debt_payments",
  "recurring_transactions",
  "bills",
  "categories",
] as const

// Deleting an account is irreversible, so the ID token must come from a
// sign-in within the last few minutes (the apps re-authenticate first).
const RECENT_LOGIN_SECONDS = 5 * 60

async function deleteRefs(store: Firestore, refs: DocumentReference[]) {
  for (let i = 0; i < refs.length; i += 400) {
    const batch = store.batch()
    for (const ref of refs.slice(i, i + 400)) batch.delete(ref)
    await batch.commit()
  }
}

async function deleteScope(store: Firestore, scopeId: string) {
  for (const name of FINANCE) {
    const snap = await store.collection(name).where("familyId", "==", scopeId).get()
    await deleteRefs(store, snap.docs.map((d) => d.ref))
  }
}

/**
 * Deletes the signed-in user's account:
 * - personal records (familyId == uid) and their profile, devices, tokens;
 * - a family they own passes to the longest-standing other member, or is
 *   deleted with its records when nobody else is in it;
 * - records they added to a family stay with that family (shared history);
 * - finally the Firebase Auth user itself.
 */
export async function POST(req: NextRequest) {
  try {
    const caller = await requireUser(req)
    await rateLimit(`account_delete_${caller.uid}`, 3, 3_600_000)

    const body = await readJson(req, 1024)
    if (body.confirm !== "DELETE") throw new HttpError(400, "confirmRequired")

    const nowSeconds = Math.floor(Date.now() / 1000)
    if (!caller.auth_time || nowSeconds - caller.auth_time > RECENT_LOGIN_SECONDS) {
      throw new HttpError(401, "reauthRequired")
    }

    const store = db()
    const uid = caller.uid
    const userRef = store.collection("users").doc(uid)
    const userSnap = await userRef.get()
    if (userSnap.data()?.systemRole === "superadmin") throw new HttpError(403, "cannotDeleteSuperadmin")

    const familyId = typeof userSnap.data()?.familyId === "string" ? (userSnap.data()?.familyId as string) : ""
    if (familyId) {
      const familyRef = store.collection("families").doc(familyId)
      const family = await familyRef.get()
      if (family.exists && family.data()?.createdBy === uid) {
        const members = await store.collection("users").where("familyId", "==", familyId).get()
        const others = members.docs
          .filter((d) => d.id !== uid)
          .sort((a, b) => (a.data().createdAt?.toMillis?.() ?? 0) - (b.data().createdAt?.toMillis?.() ?? 0))
        if (others.length > 0) {
          const heir = others[0]
          const inviteCode = family.data()?.inviteCode
          const batch = store.batch()
          batch.update(familyRef, { createdBy: heir.id })
          batch.update(heir.ref, { role: "admin" })
          if (typeof inviteCode === "string" && inviteCode) {
            batch.set(store.collection("family_invites").doc(inviteCode), { createdBy: heir.id }, { merge: true })
          }
          await batch.commit()
        } else {
          await deleteScope(store, familyId)
          const banned = await familyRef.collection("banned").get()
          await deleteRefs(store, banned.docs.map((d) => d.ref))
          const inviteCode = family.data()?.inviteCode
          if (typeof inviteCode === "string" && inviteCode) {
            await store.collection("family_invites").doc(inviteCode).delete()
          }
          await familyRef.delete()
        }
      }
    }

    await deleteScope(store, uid)
    const devices = await userRef.collection("devices").get()
    await deleteRefs(store, devices.docs.map((d) => d.ref))
    const tokens = await store.collection("fcm_tokens").where("uid", "==", uid).get()
    await deleteRefs(store, tokens.docs.map((d) => d.ref))
    await store.collection("user_public").doc(uid).delete()
    await userRef.delete()

    await store.collection("admin_audit").add({
      action: "account_deleted",
      actorUid: uid,
      targetUid: uid,
      familyId: familyId || null,
      at: FieldValue.serverTimestamp(),
    })

    await auth().deleteUser(uid)
    return NextResponse.json({ success: true })
  } catch (error) {
    return errorResponse(error, "account/delete")
  }
}

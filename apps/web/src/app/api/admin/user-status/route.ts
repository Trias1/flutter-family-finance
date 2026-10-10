import { FieldValue } from "firebase-admin/firestore"
import { NextRequest, NextResponse } from "next/server"

import { auth, db, errorResponse, HttpError, rateLimit, readJson, requireSuperadmin } from "@/lib/api-auth"

export const runtime = "nodejs"

/** Disables or re-enables a user's Firebase Auth account. */
export async function POST(req: NextRequest) {
  try {
    const caller = await requireSuperadmin(req)
    await rateLimit(`admin_status_${caller.uid}`, 30, 3_600_000)

    const body = await readJson(req, 1024)
    const uid = typeof body.uid === "string" ? body.uid.trim() : ""
    if (!uid || uid.length > 128) throw new HttpError(400, "invalidUser")
    if (typeof body.disabled !== "boolean") throw new HttpError(400, "badRequest")
    const disabled = body.disabled
    if (uid === caller.uid) throw new HttpError(400, "cannotChangeSelf")

    const target = await db().collection("users").doc(uid).get()
    if (target.data()?.systemRole === "superadmin") throw new HttpError(403, "cannotChangeSuperadmin")

    try {
      await auth().updateUser(uid, { disabled })
    } catch (error) {
      if (typeof error === "object" && error !== null && (error as { code?: string }).code === "auth/user-not-found") {
        throw new HttpError(404, "invalidUser")
      }
      throw error
    }
    // A disabled account must also lose the sessions it already has.
    if (disabled) await auth().revokeRefreshTokens(uid)

    await db().collection("admin_audit").add({
      action: disabled ? "disable_user" : "enable_user",
      actorUid: caller.uid,
      targetUid: uid,
      at: FieldValue.serverTimestamp(),
    })

    return NextResponse.json({ success: true, disabled })
  } catch (error) {
    return errorResponse(error, "admin/user-status")
  }
}

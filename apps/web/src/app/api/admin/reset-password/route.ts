import { FieldValue } from "firebase-admin/firestore"
import { NextRequest, NextResponse } from "next/server"

import { auth, db, errorResponse, HttpError, rateLimit, readJson, requireSuperadmin } from "@/lib/api-auth"

export const runtime = "nodejs"

function isStrongPassword(value: string) {
  return value.length >= 8 && value.length <= 128 && /[A-Za-z]/.test(value) && /\d/.test(value)
}

export async function POST(req: NextRequest) {
  try {
    const caller = await requireSuperadmin(req)
    await rateLimit(`admin_reset_${caller.uid}`, 10, 3_600_000)

    const body = await readJson(req, 4 * 1024)
    const uid = typeof body.uid === "string" ? body.uid.trim() : ""
    const newPassword = typeof body.newPassword === "string" ? body.newPassword : ""
    if (!uid || uid.length > 128) throw new HttpError(400, "invalidUser")
    if (!isStrongPassword(newPassword)) throw new HttpError(400, "weakPassword")
    if (uid === caller.uid) throw new HttpError(400, "cannotResetSelf")

    const target = await db().collection("users").doc(uid).get()
    if (target.data()?.systemRole === "superadmin") throw new HttpError(403, "cannotResetSuperadmin")

    await auth().updateUser(uid, { password: newPassword })
    // Sign the user out everywhere so the old password's sessions stop working.
    await auth().revokeRefreshTokens(uid)
    await db().collection("admin_audit").add({
      action: "reset_password",
      actorUid: caller.uid,
      targetUid: uid,
      at: FieldValue.serverTimestamp(),
    })

    return NextResponse.json({ success: true })
  } catch (error) {
    return errorResponse(error, "admin/reset-password")
  }
}

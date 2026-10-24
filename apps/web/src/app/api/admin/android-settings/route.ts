import { FieldValue } from "firebase-admin/firestore"
import { NextRequest, NextResponse } from "next/server"

import { db, errorResponse, HttpError, rateLimit, readJson, requireSuperadmin } from "@/lib/api-auth"

export const runtime = "nodejs"

const MAX_NOTES = 500

/**
 * Force-update switch and release notes shown in the app's update dialog.
 * With forceUpdate on, phones below the latest version cannot dismiss it.
 */
export async function POST(req: NextRequest) {
  try {
    const caller = await requireSuperadmin(req)
    await rateLimit(`admin_android_settings_${caller.uid}`, 20, 3_600_000)

    const body = await readJson(req, 4 * 1024)
    if (typeof body.forceUpdate !== "boolean") throw new HttpError(400, "badRequest")
    const releaseNotes = typeof body.releaseNotes === "string" ? body.releaseNotes.trim() : ""
    if (releaseNotes.length > MAX_NOTES) throw new HttpError(400, "notesTooLong")

    const store = db()
    await store.collection("app_config").doc("android").set(
      {
        forceUpdate: body.forceUpdate,
        releaseNotes,
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: caller.uid,
      },
      { merge: true },
    )
    await store.collection("admin_audit").add({
      action: "android_settings",
      actorUid: caller.uid,
      targetUid: null,
      forceUpdate: body.forceUpdate,
      at: FieldValue.serverTimestamp(),
    })

    return NextResponse.json({ success: true, forceUpdate: body.forceUpdate, releaseNotes })
  } catch (error) {
    return errorResponse(error, "admin/android-settings")
  }
}

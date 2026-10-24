import { FieldValue } from "firebase-admin/firestore"
import { NextRequest, NextResponse } from "next/server"

import { db, errorResponse, HttpError, rateLimit, readJson, requireSuperadmin } from "@/lib/api-auth"

export const runtime = "nodejs"

const MAX_MESSAGE = 280
const TONES = ["info", "maintenance"] as const

/**
 * A short banner shown in the Android app and on the web dashboard, e.g. a
 * maintenance window. Stored in app_config/announcement, which clients may
 * read (it holds no personal data) but only the server writes.
 */
export async function POST(req: NextRequest) {
  try {
    const caller = await requireSuperadmin(req)
    await rateLimit(`admin_announcement_${caller.uid}`, 20, 3_600_000)

    const body = await readJson(req, 4 * 1024)
    if (typeof body.active !== "boolean") throw new HttpError(400, "badRequest")
    const messageId = typeof body.messageId === "string" ? body.messageId.trim() : ""
    const messageEn = typeof body.messageEn === "string" ? body.messageEn.trim() : ""
    const tone = (TONES as readonly unknown[]).includes(body.tone) ? (body.tone as (typeof TONES)[number]) : "info"
    if (messageId.length > MAX_MESSAGE || messageEn.length > MAX_MESSAGE) throw new HttpError(400, "messageTooLong")
    if (body.active && !messageId && !messageEn) throw new HttpError(400, "messageRequired")

    const store = db()
    await store.collection("app_config").doc("announcement").set({
      active: body.active,
      messageId: messageId || messageEn,
      messageEn: messageEn || messageId,
      tone,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: caller.uid,
    })
    await store.collection("admin_audit").add({
      action: body.active ? "announcement_on" : "announcement_off",
      actorUid: caller.uid,
      targetUid: null,
      at: FieldValue.serverTimestamp(),
    })

    return NextResponse.json({ success: true })
  } catch (error) {
    return errorResponse(error, "admin/announcement")
  }
}

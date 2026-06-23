import { NextRequest, NextResponse } from "next/server"

import { adminAuth, adminDb } from "@/lib/firebase-admin"

export const runtime = "nodejs"

export async function POST(req: NextRequest) {
  try {
    if (!adminAuth || !adminDb) {
      return NextResponse.json({ error: "Server not configured" }, { status: 500 })
    }

    const token = req.headers.get("authorization")?.replace("Bearer ", "")
    if (!token) return NextResponse.json({ error: "Unauthorized" }, { status: 401 })

    const decoded = await adminAuth.verifyIdToken(token)
    const callerSnap = await adminDb.collection("users").doc(decoded.uid).get()
    if (!callerSnap.exists || callerSnap.data()?.systemRole !== "superadmin") {
      return NextResponse.json({ error: "Forbidden" }, { status: 403 })
    }

    const body = await req.json()
    const uid = String(body.uid ?? "")
    const newPassword = String(body.newPassword ?? "")

    if (!uid || newPassword.length < 6) {
      return NextResponse.json({ error: "Invalid payload" }, { status: 400 })
    }

    await adminAuth.updateUser(uid, { password: newPassword })
    return NextResponse.json({ success: true })
  } catch (e: any) {
    return NextResponse.json({ error: e.message }, { status: 500 })
  }
}

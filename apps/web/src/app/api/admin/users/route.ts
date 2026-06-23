import { NextRequest, NextResponse } from "next/server"
import { adminAuth, adminDb } from "@/lib/firebase-admin"

export const runtime = "nodejs"

export async function GET(req: NextRequest) {
  try {
    if (!adminAuth || !adminDb) {
      return NextResponse.json(
        { error: "Server not configured" },
        { status: 500 }
      )
    }

    const token = req.headers.get("authorization")?.replace("Bearer ", "")
    if (!token) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    const decoded = await adminAuth.verifyIdToken(token)
    const callerSnap = await adminDb.collection("users").doc(decoded.uid).get()
    if (!callerSnap.exists || callerSnap.data()?.systemRole !== "superadmin") {
      return NextResponse.json({ error: "Forbidden" }, { status: 403 })
    }

    const usersSnap = await adminDb.collection("user_public").get()
    const users = usersSnap.docs.map((d) => ({
      id: d.id,
      name: d.data().name ?? "User",
      createdAt: d.data().createdAt ?? null,
    }))

    return NextResponse.json({ users })
  } catch (e: any) {
    return NextResponse.json({ error: e.message }, { status: 500 })
  }
}

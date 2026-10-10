import { Timestamp } from "firebase-admin/firestore"
import { NextRequest, NextResponse } from "next/server"

import { db, errorResponse, requireSuperadmin } from "@/lib/api-auth"

export const runtime = "nodejs"

const pageSize = 400

export async function POST(req: NextRequest) {
  try {
    await requireSuperadmin(req)
    const firestore = db()
    let written = 0
    let last: FirebaseFirestore.QueryDocumentSnapshot | undefined

    for (;;) {
      let query = firestore.collection("users").orderBy("__name__").limit(pageSize)
      if (last) query = query.startAfter(last)
      const page = await query.get()
      if (page.empty) break

      const batch = firestore.batch()
      for (const userDoc of page.docs) {
        const data = userDoc.data()
        const email = typeof data.email === "string" ? data.email : ""
        const name = typeof data.name === "string" && data.name ? data.name : email.split("@")[0] || "User"
        const createdAt = data.createdAt instanceof Timestamp ? data.createdAt : Timestamp.now()
        batch.set(firestore.collection("user_public").doc(userDoc.id), { name, createdAt }, { merge: true })
      }
      await batch.commit()
      written += page.size
      last = page.docs[page.docs.length - 1]
      if (page.size < pageSize) break
    }

    return NextResponse.json({ success: true, written })
  } catch (error) {
    return errorResponse(error, "admin/backfill-user-public")
  }
}

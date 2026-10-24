import { NextRequest, NextResponse } from "next/server"

import { db, errorResponse, requireSuperadmin } from "@/lib/api-auth"

export const runtime = "nodejs"

// Creates family_invites/{code} for families made before invite docs existed.
// Existing invite docs are left alone.
export async function POST(req: NextRequest) {
  try {
    await requireSuperadmin(req)
    const firestore = db()
    const families = await firestore.collection("families").get()
    let created = 0
    let skipped = 0

    const writes = await Promise.all(
      families.docs.map(async (family) => {
        const data = family.data()
        const code = typeof data.inviteCode === "string" ? data.inviteCode.trim().toUpperCase() : ""
        if (!code) return null
        const ref = firestore.collection("family_invites").doc(code)
        const existing = await ref.get()
        if (existing.exists) return null
        return { ref, value: { familyId: family.id, familyName: typeof data.name === "string" ? data.name : "", createdBy: typeof data.createdBy === "string" ? data.createdBy : "" } }
      }),
    )

    let batch = firestore.batch()
    let pending = 0
    for (const write of writes) {
      if (!write) {
        skipped += 1
        continue
      }
      batch.set(write.ref, write.value)
      created += 1
      pending += 1
      if (pending === 400) {
        await batch.commit()
        batch = firestore.batch()
        pending = 0
      }
    }
    if (pending > 0) await batch.commit()

    return NextResponse.json({ success: true, created, skipped })
  } catch (error) {
    return errorResponse(error, "admin/backfill-family-invites")
  }
}

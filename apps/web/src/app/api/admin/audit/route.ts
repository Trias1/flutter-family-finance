import { Timestamp } from "firebase-admin/firestore"
import { NextRequest, NextResponse } from "next/server"

import { db, errorResponse, requireSuperadmin } from "@/lib/api-auth"

export const runtime = "nodejs"

const PAGE_SIZE = 50

// Extra fields shown in the log. Anything else an entry carries (family ids,
// for instance) stays on the server.
const DETAIL_FIELDS = ["versionName", "versionCode", "previousVersionCode"] as const

/** Latest admin_audit entries, newest first; `before` (millis) pages back. */
export async function GET(req: NextRequest) {
  try {
    await requireSuperadmin(req)
    const store = db()
    const before = Number(req.nextUrl.searchParams.get("before"))

    let query = store.collection("admin_audit").orderBy("at", "desc").limit(PAGE_SIZE)
    if (Number.isFinite(before) && before > 0) query = query.startAfter(Timestamp.fromMillis(before))
    const snap = await query.get()

    const uids = new Set<string>()
    for (const d of snap.docs) {
      for (const key of ["actorUid", "targetUid"]) {
        const v = d.data()[key]
        if (typeof v === "string" && v) uids.add(v)
      }
    }
    // Names only; deleted users simply have no name any more.
    const names = new Map<string, string>()
    const refs = Array.from(uids).map((uid) => store.collection("user_public").doc(uid))
    if (refs.length) {
      for (const doc of await store.getAll(...refs, { fieldMask: ["name"] })) {
        const name = doc.data()?.name
        if (typeof name === "string" && name) names.set(doc.id, name)
      }
    }

    const entries = snap.docs.map((d) => {
      const x = d.data()
      const details: Record<string, string | number> = {}
      for (const key of DETAIL_FIELDS) {
        const v = x[key]
        if (typeof v === "string" || typeof v === "number") details[key] = v
      }
      const actorUid = typeof x.actorUid === "string" ? x.actorUid : ""
      const targetUid = typeof x.targetUid === "string" ? x.targetUid : ""
      return {
        id: d.id,
        action: typeof x.action === "string" ? x.action : "unknown",
        actorUid,
        actorName: names.get(actorUid) ?? null,
        targetUid,
        targetName: names.get(targetUid) ?? null,
        at: x.at instanceof Timestamp ? x.at.toMillis() : null,
        details,
      }
    })

    const last = entries[entries.length - 1]
    return NextResponse.json({ entries, next: snap.size === PAGE_SIZE && last?.at ? last.at : null })
  } catch (error) {
    return errorResponse(error, "admin/audit")
  }
}

import { NextRequest, NextResponse } from "next/server"
import { apiBase, docId, requireSuperadmin, resourceBase, stringValue, timestampValue } from "../_lib/firebase-rest"

export const runtime = "nodejs"

export async function POST(req: NextRequest) {
  try {
    const token = req.headers.get("authorization")?.replace("Bearer ", "")
    if (!token) return NextResponse.json({ error: "Unauthorized" }, { status: 401 })

    const { sa, authHeaders } = await requireSuperadmin(token)
    const firestoreApiBase = apiBase(sa.project_id)
    const firestoreResourceBase = resourceBase(sa.project_id)

    let pageToken = ""
    let written = 0

    do {
      const url = new URL(`${firestoreApiBase}/users`)
      url.searchParams.set("pageSize", "300")
      if (pageToken) url.searchParams.set("pageToken", pageToken)
      const usersRes = await fetch(url, { headers: authHeaders })
      const usersPayload = await usersRes.json()
      if (!usersRes.ok) throw new Error(usersPayload.error?.message || "Failed to list users")

      const writes = (usersPayload.documents || []).map((userDoc: any) => {
        const id = docId(userDoc.name)
        const email = stringValue(userDoc, "email") || ""
        const name = stringValue(userDoc, "name") || email.split("@")[0] || "User"
        const createdAt = timestampValue(userDoc, "createdAt") || new Date().toISOString()
        written += 1
        return {
          update: {
            name: `${firestoreResourceBase}/user_public/${id}`,
            fields: {
              name: { stringValue: name },
              createdAt: { timestampValue: createdAt },
            },
          },
          updateMask: { fieldPaths: ["name", "createdAt"] },
        }
      })

      if (writes.length > 0) {
        const commitRes = await fetch(`https://firestore.googleapis.com/v1/projects/${sa.project_id}/databases/(default)/documents:commit`, {
          method: "POST",
          headers: { ...authHeaders, "content-type": "application/json" },
          body: JSON.stringify({ writes }),
        })
        const commitPayload = await commitRes.json()
        if (!commitRes.ok) throw new Error(commitPayload.error?.message || "Failed to write user_public")
      }

      pageToken = usersPayload.nextPageToken || ""
    } while (pageToken)

    return NextResponse.json({ success: true, written })
  } catch (e: any) {
    return NextResponse.json({ error: e.message || "Backfill failed" }, { status: 500 })
  }
}

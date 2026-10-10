import { NextRequest, NextResponse } from "next/server"

import { db, errorResponse, requireSuperadmin } from "@/lib/api-auth"

export const runtime = "nodejs"

export async function GET(req: NextRequest) {
  try {
    await requireSuperadmin(req)
    const usersSnap = await db().collection("user_public").get()
    const users = usersSnap.docs.map((d) => ({
      id: d.id,
      name: d.data().name ?? "User",
      createdAt: d.data().createdAt ?? null,
    }))
    return NextResponse.json({ users })
  } catch (error) {
    return errorResponse(error, "admin/users")
  }
}

import "server-only"

import type { DecodedIdToken } from "firebase-admin/auth"
import { FieldValue } from "firebase-admin/firestore"
import { NextRequest, NextResponse } from "next/server"

import { adminAuth, adminDb } from "@/lib/firebase-admin"

/**
 * An error that is safe to return to the caller. `code` is stable and is
 * translated on the client (messages: apiErrors.<code>).
 */
export class HttpError extends Error {
  constructor(public status: number, public code: string) {
    super(code)
  }
}

function services() {
  if (!adminAuth || !adminDb) throw new HttpError(503, "unavailable")
  return { auth: adminAuth, db: adminDb }
}

/**
 * Verifies the bearer ID token, including revocation and disabled accounts,
 * so a signed-out or disabled user loses API access right away.
 */
export async function requireUser(req: NextRequest): Promise<DecodedIdToken> {
  const header = req.headers.get("authorization") ?? ""
  const token = header.startsWith("Bearer ") ? header.slice(7).trim() : ""
  if (!token) throw new HttpError(401, "unauthenticated")
  const { auth: adminAuthService } = services()
  try {
    return await adminAuthService.verifyIdToken(token, true)
  } catch {
    throw new HttpError(401, "sessionInvalid")
  }
}

export async function requireSuperadmin(req: NextRequest) {
  const decoded = await requireUser(req)
  const { db } = services()
  const snap = await db.collection("users").doc(decoded.uid).get()
  if (snap.data()?.systemRole !== "superadmin") throw new HttpError(403, "forbidden")
  return decoded
}

/** Parses a JSON body, refusing anything over `maxBytes`. */
export async function readJson(req: NextRequest, maxBytes = 16 * 1024): Promise<Record<string, unknown>> {
  const declared = Number(req.headers.get("content-length") ?? 0)
  if (declared > maxBytes) throw new HttpError(413, "payloadTooLarge")
  const text = await req.text()
  if (Buffer.byteLength(text) > maxBytes) throw new HttpError(413, "payloadTooLarge")
  try {
    const parsed: unknown = text ? JSON.parse(text) : {}
    if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) throw new Error()
    return parsed as Record<string, unknown>
  } catch {
    throw new HttpError(400, "badRequest")
  }
}

/**
 * Fixed-window rate limit shared by every server instance, stored in
 * `rate_limits/{bucket}` (clients cannot read or write it: default-deny rule).
 */
export async function rateLimit(bucket: string, limit: number, windowMs: number) {
  const { db } = services()
  const ref = db.collection("rate_limits").doc(bucket)
  const now = Date.now()
  const allowed = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref)
    const data = snap.data()
    const windowStart = typeof data?.windowStart === "number" ? data.windowStart : 0
    const count = typeof data?.count === "number" ? data.count : 0
    if (now - windowStart >= windowMs) {
      tx.set(ref, { windowStart: now, count: 1, updatedAt: FieldValue.serverTimestamp() })
      return true
    }
    if (count >= limit) return false
    tx.update(ref, { count: count + 1, updatedAt: FieldValue.serverTimestamp() })
    return true
  })
  if (!allowed) throw new HttpError(429, "rateLimited")
}

/** Turns any thrown value into a response without leaking internals. */
export function errorResponse(error: unknown, context: string) {
  if (error instanceof HttpError) {
    return NextResponse.json({ error: error.code, code: error.code }, { status: error.status })
  }
  console.error(`[${context}]`, error)
  return NextResponse.json({ error: "server", code: "server" }, { status: 500 })
}

export function db() {
  return services().db
}

export function auth() {
  return services().auth
}

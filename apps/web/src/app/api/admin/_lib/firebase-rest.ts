import crypto from "node:crypto"

const identityApiKey = process.env.NEXT_PUBLIC_FIREBASE_API_KEY
const serviceAccountBase64 = process.env.FIREBASE_SERVICE_ACCOUNT_B64

export type ServiceAccount = {
  client_email: string
  private_key: string
  project_id: string
}

function base64Url(value: string) {
  return Buffer.from(value)
    .toString("base64")
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
}

export function getServiceAccount(): ServiceAccount | null {
  if (!serviceAccountBase64) return null
  try {
    return JSON.parse(Buffer.from(serviceAccountBase64, "base64").toString("utf-8"))
  } catch {
    return null
  }
}

export async function getAccessToken(sa: ServiceAccount) {
  const now = Math.floor(Date.now() / 1000)
  const header = base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }))
  const payload = base64Url(
    JSON.stringify({
      iss: sa.client_email,
      scope: "https://www.googleapis.com/auth/datastore",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    })
  )
  const unsigned = `${header}.${payload}`
  const signature = crypto
    .createSign("RSA-SHA256")
    .update(unsigned)
    .sign(sa.private_key, "base64")
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${unsigned}.${signature}`,
    }),
  })
  const payloadJson = await res.json()
  if (!res.ok) throw new Error(payloadJson.error_description || payloadJson.error || "OAuth token failed")
  return String(payloadJson.access_token)
}

export async function verifyFirebaseUser(idToken: string) {
  if (!identityApiKey) throw new Error("NEXT_PUBLIC_FIREBASE_API_KEY is not configured")
  const res = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${identityApiKey}`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ idToken }),
  })
  const data = await res.json()
  if (!res.ok || !data.users?.[0]?.localId) throw new Error(data.error?.message || "Invalid auth token")
  return String(data.users[0].localId)
}

export function stringValue(doc: any, field: string) {
  return doc?.fields?.[field]?.stringValue as string | undefined
}

export function boolValue(doc: any, field: string) {
  return doc?.fields?.[field]?.booleanValue as boolean | undefined
}

export function intValue(doc: any, field: string) {
  const value = doc?.fields?.[field]?.integerValue
  return value == null ? undefined : Number(value)
}

export function timestampValue(doc: any, field: string) {
  return doc?.fields?.[field]?.timestampValue as string | undefined
}

export function docId(name: string) {
  return name.split("/").pop() || ""
}

export function resourceBase(projectId: string) {
  return `projects/${projectId}/databases/(default)/documents`
}

export function apiBase(projectId: string) {
  return `https://firestore.googleapis.com/v1/${resourceBase(projectId)}`
}

export async function requireSuperadmin(token: string) {
  const sa = getServiceAccount()
  if (!sa) throw new Error("FIREBASE_SERVICE_ACCOUNT_B64 is not configured")

  const uid = await verifyFirebaseUser(token)
  const accessToken = await getAccessToken(sa)
  const authHeaders = { authorization: `Bearer ${accessToken}` }
  const callerRes = await fetch(`${apiBase(sa.project_id)}/users/${uid}`, { headers: authHeaders })
  const caller = await callerRes.json()
  if (!callerRes.ok || stringValue(caller, "systemRole") !== "superadmin") {
    throw new Error("Forbidden")
  }

  return { sa, uid, accessToken, authHeaders }
}

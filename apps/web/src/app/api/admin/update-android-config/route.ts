import { NextRequest, NextResponse } from "next/server"
import { APP_VERSION_CODE, APP_VERSION_NAME } from "@/lib/app-info"
import { boolValue, requireSuperadmin, stringValue } from "../_lib/firebase-rest"

export const runtime = "nodejs"

const APK_URL = "https://family-finance.tzm.web.id/FamilyFinance.apk"

export async function POST(req: NextRequest) {
  try {
    const token = req.headers.get("authorization")?.replace("Bearer ", "")
    if (!token) return NextResponse.json({ error: "Unauthorized" }, { status: 401 })

    const { sa, authHeaders } = await requireSuperadmin(token)
    const configUrl = `https://firestore.googleapis.com/v1/projects/${sa.project_id}/databases/(default)/documents/app_config/android`

    const existingRes = await fetch(configUrl, { headers: authHeaders })
    const existingPayload = await existingRes.json().catch(() => ({}))

    const releaseNotes = stringValue(existingPayload, "releaseNotes") || "Android config disinkronkan dari dashboard admin."
    const forceUpdate = boolValue(existingPayload, "forceUpdate") ?? false

    const patchRes = await fetch(`${configUrl}?updateMask.fieldPaths=latestVersionCode&updateMask.fieldPaths=latestVersionName&updateMask.fieldPaths=apkUrl&updateMask.fieldPaths=forceUpdate&updateMask.fieldPaths=releaseNotes&updateMask.fieldPaths=updatedAt`, {
      method: "PATCH",
      headers: { ...authHeaders, "content-type": "application/json" },
      body: JSON.stringify({
        fields: {
          latestVersionCode: { integerValue: String(APP_VERSION_CODE) },
          latestVersionName: { stringValue: APP_VERSION_NAME },
          apkUrl: { stringValue: APK_URL },
          forceUpdate: { booleanValue: forceUpdate },
          releaseNotes: { stringValue: releaseNotes },
          updatedAt: { timestampValue: new Date().toISOString() },
        },
      }),
    })
    const payload = await patchRes.json()
    if (!patchRes.ok) {
      return NextResponse.json({ error: payload.error?.message || "Failed to update android config" }, { status: patchRes.status })
    }

    return NextResponse.json({
      success: true,
      latestVersionCode: APP_VERSION_CODE,
      latestVersionName: APP_VERSION_NAME,
      apkUrl: APK_URL,
    })
  } catch (e: any) {
    return NextResponse.json({ error: e.message || "Android config sync failed" }, { status: e.message === "Forbidden" ? 403 : 500 })
  }
}

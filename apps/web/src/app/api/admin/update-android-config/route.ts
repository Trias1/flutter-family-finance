import { FieldValue } from "firebase-admin/firestore"
import { NextRequest, NextResponse } from "next/server"

import { db, errorResponse, requireSuperadmin } from "@/lib/api-auth"
import { APP_VERSION_CODE, APP_VERSION_NAME } from "@/lib/app-info"

export const runtime = "nodejs"

const APK_URL = "https://family-finance.tzm.web.id/FamilyFinance.apk"

export async function POST(req: NextRequest) {
  try {
    await requireSuperadmin(req)
    const ref = db().collection("app_config").doc("android")
    const existing = (await ref.get()).data() ?? {}

    await ref.set(
      {
        latestVersionCode: APP_VERSION_CODE,
        latestVersionName: APP_VERSION_NAME,
        apkUrl: APK_URL,
        forceUpdate: existing.forceUpdate === true,
        releaseNotes: typeof existing.releaseNotes === "string" ? existing.releaseNotes : "Android config disinkronkan dari dashboard admin.",
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    )

    return NextResponse.json({
      success: true,
      latestVersionCode: APP_VERSION_CODE,
      latestVersionName: APP_VERSION_NAME,
      apkUrl: APK_URL,
    })
  } catch (error) {
    return errorResponse(error, "admin/update-android-config")
  }
}

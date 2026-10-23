import { FieldValue } from "firebase-admin/firestore"
import { NextRequest, NextResponse } from "next/server"

import { db, errorResponse, HttpError, rateLimit, requireSuperadmin } from "@/lib/api-auth"
import { APP_VERSION_CODE, APP_VERSION_NAME } from "@/lib/app-info"

export const runtime = "nodejs"

const APK_URL = "https://finance.west-solutions.web.id/FamilyFinance.apk"
/**
 * Publishes the APK hosted with this deployment as the latest Android
 * release. scripts/release-android.mjs writes app-info.ts and copies the
 * APK in the same step, so this build's version is the APK's version; the
 * release script already publishes it, this button is the manual fallback.
 */
export async function POST(req: NextRequest) {
  try {
    const caller = await requireSuperadmin(req)
    await rateLimit(`admin_config_${caller.uid}`, 10, 3_600_000)

    const versionName = APP_VERSION_NAME
    const versionCode = APP_VERSION_CODE

    const store = db()
    const ref = store.collection("app_config").doc("android")
    const previousVersionCode = await store.runTransaction(async (tx) => {
      const existing = (await tx.get(ref)).data() ?? {}
      const current = typeof existing.latestVersionCode === "number" ? existing.latestVersionCode : 0
      // Going backwards would tell up-to-date phones they are fine on an old APK.
      if (versionCode < current) throw new HttpError(409, "versionCodeLower")
      if (versionCode === current) throw new HttpError(409, "alreadyLatest")
      tx.set(
        ref,
        {
          latestVersionCode: versionCode,
          latestVersionName: versionName,
          apkUrl: typeof existing.apkUrl === "string" && existing.apkUrl ? existing.apkUrl : APK_URL,
          forceUpdate: existing.forceUpdate === true,
          updatedAt: FieldValue.serverTimestamp(),
          updatedBy: caller.uid,
        },
        { merge: true },
      )
      return current
    })

    await store.collection("admin_audit").add({
      action: "android_config",
      actorUid: caller.uid,
      targetUid: null,
      versionName,
      versionCode,
      previousVersionCode,
      at: FieldValue.serverTimestamp(),
    })

    return NextResponse.json({ success: true, latestVersionCode: versionCode, latestVersionName: versionName })
  } catch (error) {
    return errorResponse(error, "admin/update-android-config")
  }
}

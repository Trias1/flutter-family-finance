import { FieldValue } from "firebase-admin/firestore"
import { NextRequest, NextResponse } from "next/server"

import { db, errorResponse, HttpError, rateLimit, readJson, requireSuperadmin } from "@/lib/api-auth"

export const runtime = "nodejs"

const APK_URL = "https://family-finance.tzm.web.id/FamilyFinance.apk"
const VERSION_NAME = /^\d{1,4}\.\d{1,4}\.\d{1,4}$/
// Android's own ceiling for versionCode.
const MAX_VERSION_CODE = 2_100_000_000

/**
 * Publishes the latest Android release that the app's update check compares
 * against. The admin types the APK's versionName and versionCode; the web
 * build's version is unrelated and is no longer used here.
 */
export async function POST(req: NextRequest) {
  try {
    const caller = await requireSuperadmin(req)
    await rateLimit(`admin_config_${caller.uid}`, 10, 3_600_000)

    const body = await readJson(req, 1024)
    const versionName = typeof body.versionName === "string" ? body.versionName.trim() : ""
    const versionCode = body.versionCode
    if (!VERSION_NAME.test(versionName)) throw new HttpError(400, "invalidVersionName")
    if (typeof versionCode !== "number" || !Number.isInteger(versionCode) || versionCode < 1 || versionCode > MAX_VERSION_CODE) {
      throw new HttpError(400, "invalidVersionCode")
    }

    const store = db()
    const ref = store.collection("app_config").doc("android")
    const previousVersionCode = await store.runTransaction(async (tx) => {
      const existing = (await tx.get(ref)).data() ?? {}
      const current = typeof existing.latestVersionCode === "number" ? existing.latestVersionCode : 0
      // Going backwards would tell up-to-date phones they are fine on an old APK.
      if (versionCode < current) throw new HttpError(409, "versionCodeLower")
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

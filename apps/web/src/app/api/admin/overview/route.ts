import { NextRequest, NextResponse } from "next/server"

import { adminAuth, adminDb } from "@/lib/firebase-admin"
import { APP_VERSION_CODE, APP_VERSION_NAME } from "@/lib/app-info"

export const runtime = "nodejs"

function getMillis(value: any) {
  if (!value) return null
  if (typeof value.toMillis === "function") return value.toMillis()
  if (typeof value._seconds === "number") return value._seconds * 1000
  return null
}

export async function GET(req: NextRequest) {
  try {
    if (!adminAuth || !adminDb) {
      return NextResponse.json({ error: "Server not configured" }, { status: 500 })
    }

    const token = req.headers.get("authorization")?.replace("Bearer ", "")
    if (!token) return NextResponse.json({ error: "Unauthorized" }, { status: 401 })

    const decoded = await adminAuth.verifyIdToken(token)
    const callerSnap = await adminDb.collection("users").doc(decoded.uid).get()
    if (!callerSnap.exists || callerSnap.data()?.systemRole !== "superadmin") {
      return NextResponse.json({ error: "Forbidden" }, { status: 403 })
    }

    const [usersSnap, devicesSnap, configSnap] = await Promise.all([
      adminDb.collection("user_public").get(),
      adminDb.collectionGroup("devices").get(),
      adminDb.collection("app_config").doc("android").get(),
    ])

    const latestVersionCode = (configSnap.data()?.latestVersionCode as number | undefined) ?? APP_VERSION_CODE
    const latestVersionName = (configSnap.data()?.latestVersionName as string | undefined) ?? APP_VERSION_NAME
    const now = Date.now()
    const onlineThreshold = now - 2 * 60 * 1000
    const activeDayThreshold = now - 24 * 60 * 60 * 1000

    const devicesByUser = new Map<string, any[]>()

    for (const deviceDoc of devicesSnap.docs) {
      const uid = deviceDoc.ref.parent.parent?.id
      if (!uid) continue
      const list = devicesByUser.get(uid) ?? []
      list.push({ id: deviceDoc.id, ...deviceDoc.data() })
      devicesByUser.set(uid, list)
    }

    const growthMap = new Map<string, number>()
    const activityMap = new Map<string, number>()
    const platformMap = new Map<string, number>()
    const versionMap = new Map<string, number>()

    const users = usersSnap.docs.map((doc) => {
      const data = doc.data()
      const devices = (devicesByUser.get(doc.id) ?? []).sort((a, b) => (getMillis(b.lastSeenAt) ?? 0) - (getMillis(a.lastSeenAt) ?? 0))
      const latestDevice = devices[0] ?? null
      const latestSeen = getMillis(latestDevice?.lastSeenAt)
      const online = devices.some((device) => (getMillis(device.lastSeenAt) ?? 0) >= onlineThreshold)
      const activeToday = devices.some((device) => (getMillis(device.lastSeenAt) ?? 0) >= activeDayThreshold)
      const platform = latestDevice?.platform ?? "unknown"
      const versionLabel = latestDevice ? `${latestDevice.appVersionName ?? "-"}+${latestDevice.appVersionCode ?? "-"}` : "-"
      const outdated = platform === "android" && Number(latestDevice?.appVersionCode ?? 0) < latestVersionCode

      if (platform !== "unknown") {
        platformMap.set(platform, (platformMap.get(platform) ?? 0) + 1)
      }
      if (versionLabel !== "-") {
        versionMap.set(versionLabel, (versionMap.get(versionLabel) ?? 0) + 1)
      }

      const createdAt = getMillis(data.createdAt)
      if (createdAt) {
        const day = new Date(createdAt).toISOString().slice(0, 10)
        growthMap.set(day, (growthMap.get(day) ?? 0) + 1)
      }
      if (latestSeen) {
        const day = new Date(latestSeen).toISOString().slice(0, 10)
        activityMap.set(day, (activityMap.get(day) ?? 0) + 1)
      }

      return {
        id: doc.id,
        name: data.name ?? "-",
        email: data.email ?? "-",
        role: data.role ?? "user",
        devicesCount: devices.length,
        latestSource: platform,
        latestDeviceName: latestDevice ? `${latestDevice.brand ?? "-"} ${latestDevice.model ?? ""}`.trim() : "-",
        appVersionLabel: versionLabel,
        online,
        outdated,
        activeToday,
        lastSeenAt: latestSeen,
      }
    })

    const last7Days = Array.from({ length: 7 }, (_, index) => {
      const date = new Date(now - (6 - index) * 24 * 60 * 60 * 1000)
      const key = date.toISOString().slice(0, 10)
      return {
        day: key.slice(5),
        users: growthMap.get(key) ?? 0,
        active: activityMap.get(key) ?? 0,
      }
    })

    return NextResponse.json({
      stats: {
        totalUsers: users.length,
        totalFamilies: 0,
        activeToday: users.filter((user) => user.activeToday).length,
        onlineUsers: users.filter((user) => user.online).length,
        activeDevices: devicesSnap.size,
        outdatedUsers: users.filter((user) => user.outdated).length,
        latestVersionName,
        latestVersionCode,
        webVersionName: APP_VERSION_NAME,
        webVersionCode: APP_VERSION_CODE,
        storage: null,
      },
      charts: {
        growth: last7Days,
        platforms: Array.from(platformMap.entries()).map(([name, value]) => ({ name, value })),
        versions: Array.from(versionMap.entries()).map(([name, value]) => ({ name, value })),
      },
      users: users.sort((a, b) => (b.lastSeenAt ?? 0) - (a.lastSeenAt ?? 0)),
    })
  } catch (e: any) {
    return NextResponse.json({ error: e.message }, { status: 500 })
  }
}

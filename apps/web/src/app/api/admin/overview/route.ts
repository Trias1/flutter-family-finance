import { NextRequest, NextResponse } from "next/server"

import { db, errorResponse, requireSuperadmin } from "@/lib/api-auth"
import { APP_VERSION_CODE, APP_VERSION_NAME } from "@/lib/app-info"

export const runtime = "nodejs"

type Device = { id: string; lastSeenAt?: unknown; platform?: string; appVersionName?: string; appVersionCode?: number; brand?: string; model?: string }

function getMillis(value: unknown): number | null {
  if (!value || typeof value !== "object") return null
  const v = value as { toMillis?: () => number; _seconds?: number }
  if (typeof v.toMillis === "function") return v.toMillis()
  if (typeof v._seconds === "number") return v._seconds * 1000
  return null
}

export async function GET(req: NextRequest) {
  try {
    await requireSuperadmin(req)
    const firestore = db()

    const [usersSnap, profilesSnap, devicesSnap, configSnap, familiesCount] = await Promise.all([
      firestore.collection("user_public").get(),
      firestore.collection("users").select("role", "systemRole").get(),
      firestore.collectionGroup("devices").get(),
      firestore.collection("app_config").doc("android").get(),
      firestore.collection("families").count().get(),
    ])
    const profiles = new Map(profilesSnap.docs.map((doc) => [doc.id, doc.data()]))

    const latestVersionCode = (configSnap.data()?.latestVersionCode as number | undefined) ?? APP_VERSION_CODE
    const latestVersionName = (configSnap.data()?.latestVersionName as string | undefined) ?? APP_VERSION_NAME
    const now = Date.now()
    const onlineThreshold = now - 2 * 60 * 1000
    const activeDayThreshold = now - 24 * 60 * 60 * 1000

    const devicesByUser = new Map<string, Device[]>()

    for (const deviceDoc of devicesSnap.docs) {
      const uid = deviceDoc.ref.parent.parent?.id
      if (!uid) continue
      const list = devicesByUser.get(uid) ?? []
      list.push({ id: deviceDoc.id, ...(deviceDoc.data() as Omit<Device, "id">) })
      devicesByUser.set(uid, list)
    }

    const growthMap = new Map<string, number>()
    const activityMap = new Map<string, number>()
    const platformMap = new Map<string, number>()
    const versionMap = new Map<string, number>()

    const users = usersSnap.docs.map((doc) => {
      const data = doc.data()
      const profile = profiles.get(doc.id) ?? {}
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
        role: profile.systemRole === "superadmin" ? "superadmin" : typeof profile.role === "string" ? profile.role : "member",
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
        totalFamilies: familiesCount.data().count,
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
  } catch (error) {
    return errorResponse(error, "admin/overview")
  }
}

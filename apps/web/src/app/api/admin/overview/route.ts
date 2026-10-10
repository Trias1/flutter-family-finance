import { NextRequest, NextResponse } from "next/server"

import { auth, db, errorResponse, requireSuperadmin } from "@/lib/api-auth"
import { APP_VERSION_CODE, APP_VERSION_NAME } from "@/lib/app-info"

export const runtime = "nodejs"

const MAX_PAGE_SIZE = 50
// Admins page through and search the same snapshot; this keeps that from
// re-reading every user and device on each click (per server instance).
const CACHE_MS = 30_000
const FILTERS = ["all", "online", "android", "web", "outdated", "disabled"] as const
type Filter = (typeof FILTERS)[number]

// Only these device fields ever leave the server; fcmToken and the like are
// not even read.
const DEVICE_FIELDS = ["platform", "brand", "model", "androidVersion", "appVersionName", "appVersionCode", "lastSeenAt"] as const

type Device = {
  id: string
  platform: string
  brand: string
  model: string
  osVersion: string
  appVersionName: string
  appVersionCode: number | null
  lastSeenAt: number | null
}

type Row = {
  id: string
  name: string
  devices: Device[]
  hasWeb: boolean
  latestSource: string
  appVersionLabel: string
  online: boolean
  outdated: boolean
  activeToday: boolean
  lastSeenAt: number | null
  createdAt: number | null
}

type Snapshot = {
  at: number
  rows: Row[]
  totalFamilies: number
  latestVersionName: string
  latestVersionCode: number
}

let cache: Snapshot | null = null

function getMillis(value: unknown): number | null {
  if (!value || typeof value !== "object") return null
  const v = value as { toMillis?: () => number }
  return typeof v.toMillis === "function" ? v.toMillis() : null
}

const text = (value: unknown) => (typeof value === "string" ? value.slice(0, 80) : "")

async function loadSnapshot(): Promise<Snapshot> {
  if (cache && Date.now() - cache.at < CACHE_MS) return cache
  const firestore = db()
  const [usersSnap, devicesSnap, configSnap, familiesCount] = await Promise.all([
    firestore.collection("user_public").select("name", "createdAt").get(),
    firestore.collectionGroup("devices").select(...DEVICE_FIELDS).get(),
    firestore.collection("app_config").doc("android").get(),
    firestore.collection("families").count().get(),
  ])

  const latestVersionCode = Number(configSnap.data()?.latestVersionCode ?? APP_VERSION_CODE)
  const latestVersionName = String(configSnap.data()?.latestVersionName ?? APP_VERSION_NAME)
  const now = Date.now()
  const onlineThreshold = now - 2 * 60 * 1000
  const activeDayThreshold = now - 24 * 60 * 60 * 1000

  const devicesByUser = new Map<string, Device[]>()
  for (const deviceDoc of devicesSnap.docs) {
    const uid = deviceDoc.ref.parent.parent?.id
    if (!uid) continue
    const d = deviceDoc.data()
    const list = devicesByUser.get(uid) ?? []
    list.push({
      id: deviceDoc.id,
      platform: text(d.platform) || "unknown",
      brand: text(d.brand),
      model: text(d.model),
      osVersion: text(d.androidVersion),
      appVersionName: text(d.appVersionName),
      appVersionCode: typeof d.appVersionCode === "number" ? d.appVersionCode : null,
      lastSeenAt: getMillis(d.lastSeenAt),
    })
    devicesByUser.set(uid, list)
  }

  const rows: Row[] = usersSnap.docs.map((doc) => {
    const data = doc.data()
    const devices = (devicesByUser.get(doc.id) ?? []).sort((a, b) => (b.lastSeenAt ?? 0) - (a.lastSeenAt ?? 0))
    const latest = devices[0] ?? null
    const latestAndroid = devices.find((d) => d.platform === "android") ?? null
    return {
      id: doc.id,
      name: text(data.name) || "—",
      devices,
      hasWeb: devices.some((d) => d.platform === "web"),
      latestSource: latest?.platform ?? "unknown",
      appVersionLabel: latest ? `${latest.appVersionName || "-"}+${latest.appVersionCode ?? "-"}` : "-",
      online: devices.some((d) => (d.lastSeenAt ?? 0) >= onlineThreshold),
      // Judged on the newest Android device, so a web session does not hide an old APK.
      outdated: latestAndroid !== null && (latestAndroid.appVersionCode ?? 0) < latestVersionCode,
      activeToday: devices.some((d) => (d.lastSeenAt ?? 0) >= activeDayThreshold),
      lastSeenAt: latest?.lastSeenAt ?? null,
      createdAt: getMillis(data.createdAt),
    }
  })
  rows.sort((a, b) => (b.lastSeenAt ?? 0) - (a.lastSeenAt ?? 0))

  cache = { at: now, rows, totalFamilies: familiesCount.data().count, latestVersionName, latestVersionCode }
  return cache
}

function intParam(value: string | null, fallback: number, min: number, max: number) {
  const n = Number.parseInt(value ?? "", 10)
  return Number.isFinite(n) ? Math.min(max, Math.max(min, n)) : fallback
}

export async function GET(req: NextRequest) {
  try {
    await requireSuperadmin(req)
    const params = req.nextUrl.searchParams
    const pageSize = intParam(params.get("pageSize"), 25, 1, MAX_PAGE_SIZE)
    const page = intParam(params.get("page"), 1, 1, 10_000)
    const q = (params.get("q") ?? "").trim().toLowerCase().slice(0, 64)
    const filterParam = params.get("filter") ?? "all"
    const filter: Filter = (FILTERS as readonly string[]).includes(filterParam) ? (filterParam as Filter) : "all"

    const snapshot = await loadSnapshot()
    // Settings change rarely but must show right after saving, so they are
    // read fresh instead of from the 30-second cache.
    const [androidConfig, announcementDoc] = await Promise.all([
      db().collection("app_config").doc("android").get(),
      db().collection("app_config").doc("announcement").get(),
    ])
    const ann = announcementDoc.data() ?? {}
    const { rows } = snapshot
    const now = Date.now()

    // Disabled state lives in Firebase Auth; it is only needed for the "disabled"
    // filter (all users) or for the rows on this page.
    const authState = async (uids: string[]) => {
      const out = new Map<string, boolean>()
      for (let i = 0; i < uids.length; i += 100) {
        const result = await auth().getUsers(uids.slice(i, i + 100).map((uid) => ({ uid })))
        for (const u of result.users) out.set(u.uid, u.disabled)
      }
      return out
    }

    let disabledAll: Map<string, boolean> | null = null
    if (filter === "disabled") disabledAll = await authState(rows.map((r) => r.id))

    const matching = rows.filter((r) => {
      if (q && !r.name.toLowerCase().includes(q)) return false
      if (filter === "online") return r.online
      if (filter === "android") return r.devices.some((d) => d.platform === "android")
      if (filter === "web") return r.hasWeb
      if (filter === "outdated") return r.outdated
      if (filter === "disabled") return disabledAll?.get(r.id) === true
      return true
    })

    const slice = matching.slice((page - 1) * pageSize, page * pageSize)
    const disabled = disabledAll ?? (await authState(slice.map((r) => r.id)))
    const profiles = slice.length
      ? await db().getAll(...slice.map((r) => db().collection("users").doc(r.id)), { fieldMask: ["role", "systemRole"] })
      : []
    const roles = new Map(
      profiles.map((p) => [p.id, p.data()?.systemRole === "superadmin" ? "superadmin" : p.data()?.role === "admin" ? "admin" : "member"]),
    )

    const growthMap = new Map<string, number>()
    const activityMap = new Map<string, number>()
    const versionMap = new Map<string, number>()
    for (const r of rows) {
      if (r.createdAt) {
        const day = new Date(r.createdAt).toISOString().slice(0, 10)
        growthMap.set(day, (growthMap.get(day) ?? 0) + 1)
      }
      if (r.lastSeenAt) {
        const day = new Date(r.lastSeenAt).toISOString().slice(0, 10)
        activityMap.set(day, (activityMap.get(day) ?? 0) + 1)
      }
      // Only phones used in the last 30 days say how far an update has spread.
      if (r.appVersionLabel !== "-" && (r.lastSeenAt ?? 0) >= now - 30 * 86_400_000) {
        versionMap.set(r.appVersionLabel, (versionMap.get(r.appVersionLabel) ?? 0) + 1)
      }
    }
    const growth = Array.from({ length: 14 }, (_, i) => {
      const key = new Date(now - (13 - i) * 86_400_000).toISOString().slice(0, 10)
      return { day: key.slice(5), users: growthMap.get(key) ?? 0, active: activityMap.get(key) ?? 0 }
    })

    return NextResponse.json({
      stats: {
        totalUsers: rows.length,
        totalFamilies: snapshot.totalFamilies,
        onlineUsers: rows.filter((r) => r.online).length,
        activeToday: rows.filter((r) => r.activeToday).length,
        outdatedUsers: rows.filter((r) => r.outdated).length,
        activeDevices: rows.reduce((s, r) => s + r.devices.length, 0),
        latestVersionName: snapshot.latestVersionName,
        latestVersionCode: snapshot.latestVersionCode,
        webVersionName: APP_VERSION_NAME,
        webVersionCode: APP_VERSION_CODE,
      },
      growth,
      release: {
        forceUpdate: androidConfig.data()?.forceUpdate === true,
        releaseNotes: typeof androidConfig.data()?.releaseNotes === "string" ? (androidConfig.data()?.releaseNotes as string) : "",
      },
      announcement: {
        active: ann.active === true,
        messageId: typeof ann.messageId === "string" ? ann.messageId : "",
        messageEn: typeof ann.messageEn === "string" ? ann.messageEn : "",
        tone: ann.tone === "maintenance" ? "maintenance" : "info",
      },
      versions: Array.from(versionMap, ([name, value]) => ({ name, value })).sort((a, b) => b.value - a.value),
      users: slice.map((r) => ({
        id: r.id,
        name: r.name,
        role: roles.get(r.id) ?? "member",
        disabled: disabled.get(r.id) === true,
        devices: r.devices,
        hasWeb: r.hasWeb,
        latestSource: r.latestSource,
        appVersionLabel: r.appVersionLabel,
        online: r.online,
        outdated: r.outdated,
        lastSeenAt: r.lastSeenAt,
      })),
      page,
      pageSize,
      total: matching.length,
    })
  } catch (error) {
    return errorResponse(error, "admin/overview")
  }
}

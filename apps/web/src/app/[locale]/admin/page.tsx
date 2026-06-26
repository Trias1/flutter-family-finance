"use client"

import { useEffect, useMemo, useState } from "react"
import { onAuthStateChanged } from "firebase/auth"
import { collection, collectionGroup, doc, getDoc, getDocs } from "firebase/firestore"
import { useTranslations } from "next-intl"
import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts"

import AdminShell from "@/components/AdminShell"
import { auth, db } from "@/lib/firebase"
import { APP_NAME, APP_VERSION_CODE, APP_VERSION_NAME } from "@/lib/app-info"
import { startWebPresence } from "@/lib/web-presence"

type OverviewResponse = {
  stats: {
    totalUsers: number
    totalFamilies: number
    activeToday: number
    onlineUsers: number
    activeDevices: number
    outdatedUsers: number
    latestVersionName: string
    latestVersionCode: number
    webVersionName: string
    webVersionCode: number
    storage: { files: number; bytes: number; megabytes: number } | null
  }
  charts: {
    growth: { day: string; users: number; active: number }[]
    platforms: { name: string; value: number }[]
    versions: { name: string; value: number }[]
  }
  users: {
    id: string
    name: string
    devicesCount: number
    latestSource: string
    latestDeviceName: string
    appVersionLabel: string
    online: boolean
    outdated: boolean
    activeToday: boolean
    lastSeenAt: number | null
  }[]
}

function formatLastSeen(value: number | null) {
  if (!value) return "Belum ada"
  return new Intl.DateTimeFormat("id-ID", {
    day: "2-digit",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(value))
}

export default function AdminPage() {
  const t = useTranslations()
  const [authorized, setAuthorized] = useState(false)
  const [loading, setLoading] = useState(true)
  const [overview, setOverview] = useState<OverviewResponse | null>(null)
  const [error, setError] = useState("")
  const [currentUser, setCurrentUser] = useState<import("firebase/auth").User | null>(null)
  const [search, setSearch] = useState("")
  const [filter, setFilter] = useState<"all" | "online" | "android" | "web" | "outdated">("all")
  const [backfillBusy, setBackfillBusy] = useState(false)
  const [syncConfigBusy, setSyncConfigBusy] = useState(false)

  useEffect(() => {
    let stopPresence: (() => void) | undefined

    const unsub = onAuthStateChanged(auth, async (u) => {
      if (!u) {
        stopPresence?.()
        setAuthorized(false)
        setLoading(false)
        return
      }
      setCurrentUser(u)

      const snap = await getDoc(doc(db, "users", u.uid))
      if (snap.data()?.systemRole !== "superadmin") {
        setAuthorized(false)
        setLoading(false)
        return
      }

      setAuthorized(true)
      stopPresence?.()
      stopPresence = startWebPresence(u.uid, u.email)
      try {
        const [usersSnap, devicesSnap, configSnap] = await Promise.all([
          getDocs(collection(db, "user_public")),
          getDocs(collectionGroup(db, "devices")),
          getDoc(doc(db, "app_config", "android")),
        ])

        const latestVersionCode = Number(configSnap.data()?.latestVersionCode ?? 0)
        const latestVersionName = String(configSnap.data()?.latestVersionName ?? "-")
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

        const getMillis = (value: any) => {
          if (!value) return null
          if (typeof value.toMillis === "function") return value.toMillis()
          if (typeof value.seconds === "number") return value.seconds * 1000
          return null
        }

        const users = usersSnap.docs.map((userDoc) => {
          const data = userDoc.data()
          const devices = (devicesByUser.get(userDoc.id) ?? []).sort((a, b) => (getMillis(b.lastSeenAt) ?? 0) - (getMillis(a.lastSeenAt) ?? 0))
          const latestDevice = devices[0] ?? null
          const latestSeen = getMillis(latestDevice?.lastSeenAt)
          const online = devices.some((device) => (getMillis(device.lastSeenAt) ?? 0) >= onlineThreshold)
          const activeToday = devices.some((device) => (getMillis(device.lastSeenAt) ?? 0) >= activeDayThreshold)
          const latestSource = latestDevice?.platform ?? "unknown"
          const appVersionLabel = latestDevice ? `${latestDevice.appVersionName ?? "-"}+${latestDevice.appVersionCode ?? "-"}` : "-"
          const outdated = latestSource === "android" && Number(latestDevice?.appVersionCode ?? 0) < latestVersionCode

          if (latestSource !== "unknown") {
            platformMap.set(latestSource, (platformMap.get(latestSource) ?? 0) + 1)
          }
          if (appVersionLabel !== "-") {
            versionMap.set(appVersionLabel, (versionMap.get(appVersionLabel) ?? 0) + 1)
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
            id: userDoc.id,
            name: data.name ?? "-",
            devicesCount: devices.length,
            latestSource,
            latestDeviceName: latestDevice ? `${latestDevice.brand ?? "-"} ${latestDevice.model ?? ""}`.trim() : "-",
            appVersionLabel,
            online,
            outdated,
            activeToday,
            lastSeenAt: latestSeen,
          }
        })

        const growth = Array.from({ length: 7 }, (_, index) => {
          const date = new Date(now - (6 - index) * 24 * 60 * 60 * 1000)
          const key = date.toISOString().slice(0, 10)
          return { day: key.slice(5), users: growthMap.get(key) ?? 0, active: activityMap.get(key) ?? 0 }
        })

        setOverview({
          stats: {
            totalUsers: users.length,
            totalFamilies: 0,
            activeToday: users.filter((item) => item.activeToday).length,
            onlineUsers: users.filter((item) => item.online).length,
            activeDevices: devicesSnap.size,
            outdatedUsers: users.filter((item) => item.outdated).length,
            latestVersionName,
            latestVersionCode,
            webVersionName: APP_VERSION_NAME,
            webVersionCode: APP_VERSION_CODE,
            storage: null,
          },
          charts: {
            growth,
            platforms: Array.from(platformMap.entries()).map(([name, value]) => ({ name, value })),
            versions: Array.from(versionMap.entries()).map(([name, value]) => ({ name, value })),
          },
          users: users.sort((a, b) => (b.lastSeenAt ?? 0) - (a.lastSeenAt ?? 0)),
        })
      } catch (err: any) {
        setError(err.message || "Gagal memuat data Firestore admin")
      } finally {
        setLoading(false)
      }
    })

    return () => {
      stopPresence?.()
      unsub()
    }
  }, [])

  const filteredUsers = useMemo(() => {
    const users = overview?.users ?? []
    return users.filter((user) => {
      const keyword = search.trim().toLowerCase()
      const matchesSearch = !keyword || [user.name, user.latestDeviceName].some((value) => value.toLowerCase().includes(keyword))
      const matchesFilter =
        filter === "all" ||
        (filter === "online" && user.online) ||
        (filter === "android" && user.latestSource === "android") ||
        (filter === "web" && user.latestSource === "web") ||
        (filter === "outdated" && user.outdated)
      return matchesSearch && matchesFilter
    })
  }, [filter, overview?.users, search])

  const handleBackfillPublicUsers = async () => {
    if (!currentUser) return
    setBackfillBusy(true)
    setError("")
    try {
      const token = await currentUser.getIdToken()
      const res = await fetch("/api/admin/backfill-user-public", {
        method: "POST",
        headers: { authorization: `Bearer ${token}` },
      })
      const contentType = res.headers.get("content-type") || ""
      const payload = contentType.includes("application/json")
        ? await res.json()
        : { error: (await res.text()).slice(0, 180) }
      if (!res.ok) throw new Error(payload.error || "Backfill failed")
      window.alert(t("admin.syncedUsernames", { count: payload.written }))
      window.location.reload()
    } catch (err: any) {
      setError(err.message)
    } finally {
      setBackfillBusy(false)
    }
  }

  const handleSyncAndroidConfig = async () => {
    if (!currentUser) return
    setSyncConfigBusy(true)
    setError("")
    try {
      const token = await currentUser.getIdToken()
      const res = await fetch("/api/admin/update-android-config", {
        method: "POST",
        headers: { authorization: `Bearer ${token}` },
      })
      const contentType = res.headers.get("content-type") || ""
      const payload = contentType.includes("application/json") ? await res.json() : { error: (await res.text()).slice(0, 180) }
      if (!res.ok) throw new Error(payload.error || "Android config sync failed")
      window.alert(t("admin.androidConfigSynced", { versionName: payload.latestVersionName, versionCode: payload.latestVersionCode }))
      window.location.reload()
    } catch (err: any) {
      setError(err.message)
    } finally {
      setSyncConfigBusy(false)
    }
  }

  const content = (
    <div className="mx-auto max-w-7xl space-y-6">
      <div id="overview" className="flex flex-col gap-3 lg:flex-row lg:items-end lg:justify-between scroll-mt-24">
        <div>
          <p className="text-sm font-medium" style={{ color: "var(--primary)" }}>{t("admin.adminMonitoring")}</p>
          <h1 className="text-3xl font-bold" style={{ color: "var(--text-primary)" }}>{APP_NAME} {t("admin.dashboardTitle")}</h1>
          <p className="mt-1 text-sm" style={{ color: "var(--text-secondary)" }}>
            {t("admin.dashboardDesc")}
          </p>
        </div>
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
          <button
            onClick={handleSyncAndroidConfig}
            disabled={syncConfigBusy}
            className="rounded-2xl border px-4 py-3 text-sm font-semibold transition hover:scale-[1.02] disabled:cursor-wait disabled:opacity-60"
            style={{ backgroundColor: "var(--bg-card)", borderColor: "var(--border)", color: "var(--text-primary)", boxShadow: "var(--shadow-soft)" }}
          >
            {syncConfigBusy ? t("admin.processing") : t("admin.syncAndroidConfig")}
          </button>
          <button
            onClick={handleBackfillPublicUsers}
            disabled={backfillBusy}
            className="rounded-2xl border px-4 py-3 text-sm font-semibold transition hover:scale-[1.02] disabled:cursor-wait disabled:opacity-60"
            style={{ backgroundColor: "var(--primary)", borderColor: "var(--primary)", color: "white", boxShadow: "var(--shadow-soft)" }}
          >
            {backfillBusy ? t("admin.processing") : t("admin.syncLegacyUsers")}
          </button>
          <div className="rounded-2xl border px-4 py-3" style={{ backgroundColor: "var(--bg-card)", borderColor: "var(--border)", boxShadow: "var(--shadow-soft)" }}>
          <p className="text-xs uppercase tracking-[0.2em]" style={{ color: "var(--text-muted)" }}>{t("admin.latestAndroid")}</p>
          <p className="text-lg font-semibold" style={{ color: "var(--text-primary)" }}>
            v{overview?.stats.latestVersionName}+{overview?.stats.latestVersionCode}
          </p>
          <p className="text-xs" style={{ color: "var(--text-secondary)" }}>
            {t("admin.webVersion")} v{overview?.stats.webVersionName}+{overview?.stats.webVersionCode}
          </p>
          </div>
        </div>
      </div>

      {error && (
        <div className="rounded-2xl border px-4 py-3 text-sm" style={{ backgroundColor: "rgba(239,83,80,0.08)", borderColor: "rgba(239,83,80,0.2)", color: "var(--expense)" }}>
          {error}
        </div>
      )}

      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <StatCard title={t("admin.totalUsers")} value={overview?.stats.totalUsers ?? 0} hint={t("admin.registeredAccounts")} />
        <StatCard title={t("admin.onlineNow")} value={overview?.stats.onlineUsers ?? 0} hint={t("admin.activeIn2Minutes")} accent="#42A5F5" />
        <StatCard title={t("admin.privacyMode")} value="ON" hint={t("admin.privacyModeHint")} accent="#8B5CF6" />
        <StatCard title={t("admin.needsUpdate")} value={overview?.stats.outdatedUsers ?? 0} hint={t("admin.oldAndroidVersion")} accent="#F59E0B" />
        <StatCard title={t("admin.activeToday")} value={overview?.stats.activeToday ?? 0} hint={t("admin.active24Hours")} accent="#10B981" />
        <StatCard title={t("admin.activeDevices")} value={overview?.stats.activeDevices ?? 0} hint={t("admin.androidAndWebSessions")} accent="#EC4899" />
        <StatCard title={t("admin.storageFiles")} value={overview?.stats.storage?.files ?? 0} hint={overview?.stats.storage ? `${overview.stats.storage.megabytes} MB bucket snapshot` : t("admin.storageUnavailable")} accent="#6366F1" />
        <StatCard title={t("admin.storageBytes")} value={overview?.stats.storage?.megabytes ?? 0} hint={t("admin.estimatedFileSize")} suffix="MB" accent="#0EA5E9" />
      </div>


      <div id="charts" className="scroll-mt-24">
        <Panel title={t("admin.growthTitle")}>
          <div className="h-80">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={overview?.charts.growth ?? []}>
                <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" />
                <XAxis dataKey="day" stroke="var(--text-muted)" />
                <YAxis stroke="var(--text-muted)" />
                <Tooltip />
                <Bar dataKey="users" fill="#6B3F2A" radius={[6, 6, 0, 0]} />
                <Bar dataKey="active" fill="#42A5F5" radius={[6, 6, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </Panel>

      </div>

        <Panel title={t("admin.userMonitoring")}>
        <div id="users" className="scroll-mt-24" />
        <div className="mb-4 flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder={t("admin.searchPlaceholder")}
            className="w-full rounded-xl border px-4 py-2.5 text-sm outline-none lg:max-w-sm"
            style={{ backgroundColor: "var(--bg-card)", borderColor: "var(--border)", color: "var(--text-primary)" }}
          />
          <div className="flex flex-wrap gap-2">
            {[
              ["all", t("admin.all")],
              ["online", t("admin.online")],
              ["android", t("admin.android")],
              ["web", t("admin.web")],
              ["outdated", t("admin.needsUpdate")],
            ].map(([value, label]) => (
              <button
                key={value}
                onClick={() => setFilter(value as typeof filter)}
                className="rounded-xl border px-3 py-2 text-sm font-medium"
                style={{
                  backgroundColor: filter === value ? "var(--primary-bg)" : "var(--bg-card)",
                  borderColor: filter === value ? "var(--primary)" : "var(--border)",
                  color: filter === value ? "var(--primary)" : "var(--text-secondary)",
                }}
              >
                {label}
              </button>
            ))}
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="min-w-full text-sm">
            <thead>
              <tr style={{ color: "var(--text-muted)" }}>
                <th className="px-3 py-3 text-left font-semibold">{t("admin.user")}</th>
                <th className="px-3 py-3 text-left font-semibold">{t("admin.status")}</th>
                <th className="px-3 py-3 text-left font-semibold">{t("admin.source")}</th>
                <th className="px-3 py-3 text-left font-semibold">{t("admin.version")}</th>
                <th className="px-3 py-3 text-left font-semibold">{t("admin.lastSeen")}</th>
              </tr>
            </thead>
            <tbody>
              {filteredUsers.map((user) => (
                <tr key={user.id} className="border-t" style={{ borderColor: "var(--border)" }}>
                  <td className="px-3 py-4">
                    <div className="font-semibold" style={{ color: "var(--text-primary)" }}>{user.name}</div>
                    <div className="text-xs" style={{ color: "var(--text-muted)" }}>{user.devicesCount} {t("admin.device")}</div>
                  </td>
                  <td className="px-3 py-4">
                    <span className="rounded-full px-2.5 py-1 text-xs font-semibold" style={{ backgroundColor: user.online ? "rgba(16,185,129,0.12)" : "var(--surface-soft)", color: user.online ? "#10B981" : "var(--text-secondary)" }}>
                      {user.online ? t("admin.online") : t("admin.offline")}
                    </span>
                  </td>
                  <td className="px-3 py-4">
                    <div className="capitalize" style={{ color: "var(--text-primary)" }}>{user.latestSource}</div>
                    <div className="text-xs" style={{ color: "var(--text-muted)" }}>{user.latestDeviceName}</div>
                  </td>
                  <td className="px-3 py-4">
                    <div style={{ color: "var(--text-primary)" }}>{user.appVersionLabel}</div>
                     {user.outdated && <div className="text-xs font-medium" style={{ color: "var(--warning-text)" }}>{t("admin.updateRequired")}</div>}
                  </td>
                  <td className="px-3 py-4" style={{ color: "var(--text-secondary)" }}>{formatLastSeen(user.lastSeenAt)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Panel>

      <div id="registry" className="scroll-mt-24" />
      <Panel title={t("admin.usersRegistry")}>
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <MiniStat label={t("admin.totalUsers")} value={overview?.stats.totalUsers ?? 0} />
          <MiniStat label={t("admin.privateData")} value={t("admin.safe")} />
          <MiniStat label={t("admin.email")} value={t("admin.hidden")} />
          <MiniStat label={t("admin.family")} value={t("admin.hidden")} />
          <MiniStat label={t("admin.activeToday")} value={overview?.stats.activeToday ?? 0} />
          <MiniStat label={t("admin.onlineNow")} value={overview?.stats.onlineUsers ?? 0} />
          <MiniStat label={t("admin.finance")} value={t("admin.blocked")} />
          <MiniStat label={t("admin.totalDevices")} value={overview?.stats.activeDevices ?? 0} />
        </div>
      </Panel>

      <div id="devices" className="scroll-mt-24" />
      <Panel title={t("admin.devicePresence")}>
        <div className="mb-4 grid gap-4 sm:grid-cols-3">
          <MiniStat label={t("admin.android")} value={overview?.charts.platforms.find(p => p.name === "android")?.value ?? 0} />
          <MiniStat label={t("admin.web")} value={overview?.charts.platforms.find(p => p.name === "web")?.value ?? 0} />
          <MiniStat label={t("admin.unknown")} value={overview?.charts.platforms.reduce((s, p) => s + (p.name === "android" || p.name === "web" ? 0 : p.value), 0) ?? 0} />
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full text-sm">
            <thead>
              <tr style={{ color: "var(--text-muted)" }}>
                <th className="px-3 py-2 text-left font-semibold">{t("admin.user")}</th>
                <th className="px-3 py-2 text-left font-semibold">{t("admin.platform")}</th>
                <th className="px-3 py-2 text-left font-semibold">{t("admin.deviceLabel")}</th>
                <th className="px-3 py-2 text-left font-semibold">{t("admin.version")}</th>
                <th className="px-3 py-2 text-left font-semibold">{t("admin.status")}</th>
                <th className="px-3 py-2 text-left font-semibold">{t("admin.lastSeen")}</th>
              </tr>
            </thead>
            <tbody>
              {overview?.users.slice(0, 20).map((user) => (
                <tr key={user.id} className="border-t" style={{ borderColor: "var(--border)" }}>
                  <td className="px-3 py-3">
                    <div className="font-medium" style={{ color: "var(--text-primary)" }}>{user.name}</div>
                    <div className="text-xs" style={{ color: "var(--text-muted)" }}>{t("admin.usernameOnly")}</div>
                  </td>
                  <td className="px-3 py-3 capitalize" style={{ color: "var(--text-primary)" }}>{user.latestSource}</td>
                  <td className="px-3 py-3 text-xs" style={{ color: "var(--text-secondary)" }}>{user.latestDeviceName}</td>
                  <td className="px-3 py-3 text-xs" style={{ color: "var(--text-secondary)" }}>{user.appVersionLabel}</td>
                  <td className="px-3 py-3">
                    <span className="rounded-full px-2 py-0.5 text-xs font-semibold" style={{ backgroundColor: user.online ? "rgba(16,185,129,0.12)" : "var(--surface-soft)", color: user.online ? "#10B981" : "var(--text-secondary)" }}>
                      {user.online ? t("admin.online") : t("admin.offline")}
                    </span>
                  </td>
                  <td className="px-3 py-3 text-xs" style={{ color: "var(--text-muted)" }}>{formatLastSeen(user.lastSeenAt)}</td>
                </tr>
              ))}
            </tbody>
          </table>
          {(overview?.users.length ?? 0) > 20 && (
            <p className="mt-2 text-xs" style={{ color: "var(--text-muted)" }}>{t("admin.showingUsers", { count: overview?.users.length ?? 0 })}</p>
          )}
        </div>
      </Panel>

      <div id="versions" className="scroll-mt-24" />
      <Panel title={t("admin.versionControl")}>
        <div className="mb-4 grid gap-4 sm:grid-cols-4">
          <MiniStat label={t("admin.latestAndroid")} value={`v${overview?.stats.latestVersionName}+${overview?.stats.latestVersionCode}`} />
          <MiniStat label={t("admin.webVersion")} value={`v${overview?.stats.webVersionName}+${overview?.stats.webVersionCode}`} />
          <MiniStat label={t("admin.userOutdated")} value={overview?.stats.outdatedUsers ?? 0} />
          <MiniStat label={t("admin.totalVersions")} value={overview?.charts.versions.length ?? 0} />
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full text-sm">
            <thead>
              <tr style={{ color: "var(--text-muted)" }}>
                <th className="px-3 py-2 text-left font-semibold">{t("admin.versionDistribution")}</th>
                <th className="px-3 py-2 text-left font-semibold">{t("admin.count")}</th>
              </tr>
            </thead>
            <tbody>
              {overview?.charts.versions.map((v) => (
                <tr key={v.name} className="border-t" style={{ borderColor: "var(--border)" }}>
                  <td className="px-3 py-3" style={{ color: "var(--text-primary)" }}>{v.name}</td>
                  <td className="px-3 py-3" style={{ color: "var(--text-secondary)" }}>{v.value} {t("admin.usersLabel")}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Panel>
    </div>
  )

  return (
    <AdminShell user={currentUser}>
      {loading ? (
        <div className="flex min-h-[50vh] items-center justify-center">
          <div className="h-10 w-10 animate-spin rounded-full border-4 border-t-transparent" style={{ borderColor: "var(--border)", borderTopColor: "var(--primary)" }} />
        </div>
      ) : !authorized ? (
        <div className="rounded-2xl border px-6 py-10 text-center" style={{ backgroundColor: "var(--bg-card)", borderColor: "var(--border)", color: "var(--expense)" }}>
          {t("admin.noPermission")}
        </div>
      ) : (
        content
      )}
    </AdminShell>
  )
}

function MiniStat({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-xl border px-4 py-3" style={{ backgroundColor: "var(--bg-card)", borderColor: "var(--border)" }}>
      <p className="text-xs uppercase tracking-[0.18em]" style={{ color: "var(--text-muted)" }}>{label}</p>
      <p className="mt-1 text-lg font-bold" style={{ color: "var(--text-primary)" }}>{value}</p>
    </div>
  )
}

function StatCard({ title, value, hint, accent = "#6B3F2A", suffix = "" }: { title: string; value: number | string; hint: string; accent?: string; suffix?: string }) {
  return (
    <div className="rounded-2xl border p-5 smooth-card" style={{ backgroundColor: "var(--bg-card)", borderColor: "var(--border)", boxShadow: "var(--shadow-soft)" }}>
      <p className="text-xs uppercase tracking-[0.18em]" style={{ color: "var(--text-muted)" }}>{title}</p>
      <div className="mt-3 flex items-end gap-2">
        <p className="text-3xl font-bold" style={{ color: accent }}>{value}{suffix}</p>
      </div>
      <p className="mt-2 text-sm" style={{ color: "var(--text-secondary)" }}>{hint}</p>
    </div>
  )
}

function Panel({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="rounded-2xl border p-5" style={{ backgroundColor: "var(--bg-card)", borderColor: "var(--border)", boxShadow: "var(--shadow-soft)" }}>
      <h2 className="mb-4 text-lg font-semibold" style={{ color: "var(--text-primary)" }}>{title}</h2>
      {children}
    </section>
  )
}

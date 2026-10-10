"use client"

import { useEffect, useMemo, useState } from "react"
import { onAuthStateChanged, type User } from "firebase/auth"
import { collection, collectionGroup, doc, getDoc, getDocs } from "firebase/firestore"
import { Search } from "lucide-react"
import { useLocale, useTranslations } from "next-intl"
import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts"

import AdminShell from "@/components/AdminShell"
import { EmptyState, PageHeader, Pill, Section, Skeleton } from "@/components/ui"
import { APP_VERSION_CODE, APP_VERSION_NAME } from "@/lib/app-info"
import { auth, db } from "@/lib/firebase"
import { useRouter } from "@/lib/i18n"
import { startWebPresence } from "@/lib/web-presence"

type AdminUser = {
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
}

type Overview = {
  totalUsers: number
  onlineUsers: number
  activeToday: number
  outdatedUsers: number
  activeDevices: number
  latestVersionName: string
  latestVersionCode: number
  growth: { day: string; users: number; active: number }[]
  versions: { name: string; value: number }[]
  users: AdminUser[]
}

type Filter = "all" | "online" | "android" | "web" | "outdated"

function getMillis(raw: unknown) {
  if (!raw || typeof raw !== "object") return null
  const value = raw as { toMillis?: () => number; seconds?: number }
  if (typeof value.toMillis === "function") return value.toMillis()
  if (typeof value.seconds === "number") return value.seconds * 1000
  return null
}

async function loadOverview(): Promise<Overview> {
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

  const devicesByUser = new Map<string, Array<Record<string, unknown>>>()
  for (const deviceDoc of devicesSnap.docs) {
    const uid = deviceDoc.ref.parent.parent?.id
    if (!uid) continue
    const list = devicesByUser.get(uid) ?? []
    list.push(deviceDoc.data())
    devicesByUser.set(uid, list)
  }

  const growthMap = new Map<string, number>()
  const activityMap = new Map<string, number>()
  const versionMap = new Map<string, number>()

  const users: AdminUser[] = usersSnap.docs.map((userDoc) => {
    const data = userDoc.data()
    const devices = (devicesByUser.get(userDoc.id) ?? []).sort((a, b) => (getMillis(b.lastSeenAt) ?? 0) - (getMillis(a.lastSeenAt) ?? 0))
    const latest = devices[0]
    const latestSeen = getMillis(latest?.lastSeenAt)
    const latestSource = typeof latest?.platform === "string" ? latest.platform : "unknown"
    const appVersionLabel = latest ? `${latest.appVersionName ?? "-"}+${latest.appVersionCode ?? "-"}` : "-"

    if (appVersionLabel !== "-") versionMap.set(appVersionLabel, (versionMap.get(appVersionLabel) ?? 0) + 1)
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
      name: typeof data.name === "string" && data.name ? data.name : "—",
      devicesCount: devices.length,
      latestSource,
      latestDeviceName: latest ? `${latest.brand ?? ""} ${latest.model ?? ""}`.trim() || "—" : "—",
      appVersionLabel,
      online: devices.some((d) => (getMillis(d.lastSeenAt) ?? 0) >= onlineThreshold),
      outdated: latestSource === "android" && Number(latest?.appVersionCode ?? 0) < latestVersionCode,
      activeToday: devices.some((d) => (getMillis(d.lastSeenAt) ?? 0) >= activeDayThreshold),
      lastSeenAt: latestSeen,
    }
  })

  const growth = Array.from({ length: 14 }, (_, i) => {
    const key = new Date(now - (13 - i) * 86_400_000).toISOString().slice(0, 10)
    return { day: key.slice(5), users: growthMap.get(key) ?? 0, active: activityMap.get(key) ?? 0 }
  })

  return {
    totalUsers: users.length,
    onlineUsers: users.filter((u) => u.online).length,
    activeToday: users.filter((u) => u.activeToday).length,
    outdatedUsers: users.filter((u) => u.outdated).length,
    activeDevices: devicesSnap.size,
    latestVersionName,
    latestVersionCode,
    growth,
    versions: Array.from(versionMap, ([name, value]) => ({ name, value })).sort((a, b) => b.value - a.value),
    users: users.sort((a, b) => (b.lastSeenAt ?? 0) - (a.lastSeenAt ?? 0)),
  }
}

async function callAdminApi(user: User, path: string) {
  const token = await user.getIdToken()
  const res = await fetch(path, { method: "POST", headers: { authorization: `Bearer ${token}` } })
  const payload = (res.headers.get("content-type") ?? "").includes("application/json") ? await res.json() : {}
  if (!res.ok) throw new Error(typeof payload.code === "string" ? payload.code : "server")
  return payload as Record<string, unknown>
}

export default function AdminPage() {
  const t = useTranslations("admin")
  const tApi = useTranslations("apiErrors")
  const locale = useLocale()
  const apiError = (err: unknown) => {
    const code = err instanceof Error ? err.message : "server"
    return tApi.has(code) ? tApi(code) : tApi("server")
  }
  const router = useRouter()
  const [user, setUser] = useState<User | null>(null)
  const [state, setState] = useState<"loading" | "denied" | "ready">("loading")
  const [overview, setOverview] = useState<Overview | null>(null)
  const [notice, setNotice] = useState<{ tone: "ok" | "error"; text: string } | null>(null)
  const [search, setSearch] = useState("")
  const [filter, setFilter] = useState<Filter>("all")
  const [busy, setBusy] = useState<"" | "backfill" | "config" | "invites">("")

  useEffect(() => {
    let stopPresence: (() => void) | undefined
    const unsub = onAuthStateChanged(auth, async (u) => {
      stopPresence?.()
      if (!u) {
        router.replace("/login")
        return
      }
      setUser(u)
      // Development-only layout review with sample data; dropped from production builds.
      if (process.env.NODE_ENV === "development" && new URLSearchParams(window.location.search).get("demo") === "1") {
        const { buildDemoAdminOverview } = await import("@/lib/demo-data")
        setOverview(buildDemoAdminOverview())
        setState("ready")
        return
      }
      const snap = await getDoc(doc(db, "users", u.uid)).catch(() => null)
      if (snap?.data()?.systemRole !== "superadmin") {
        setState("denied")
        router.replace("/dashboard")
        return
      }
      stopPresence = startWebPresence(u.uid, u.email)
      try {
        setOverview(await loadOverview())
      } catch {
        setNotice({ tone: "error", text: t("loadFailed") })
      }
      setState("ready")
    })
    return () => {
      stopPresence?.()
      unsub()
    }
  }, [router, t])

  const users = useMemo(() => {
    const keyword = search.trim().toLowerCase()
    return (overview?.users ?? []).filter((u) => {
      if (keyword && ![u.name, u.latestDeviceName].some((v) => v.toLowerCase().includes(keyword))) return false
      if (filter === "online") return u.online
      if (filter === "android" || filter === "web") return u.latestSource === filter
      if (filter === "outdated") return u.outdated
      return true
    })
  }, [overview?.users, search, filter])

  const run = async (kind: "backfill" | "config" | "invites") => {
    if (!user) return
    setBusy(kind)
    setNotice(null)
    try {
      if (kind === "invites") {
        const payload = await callAdminApi(user, "/api/admin/backfill-family-invites")
        setNotice({ tone: "ok", text: t("invitesSynced", { count: Number(payload.created ?? 0) }) })
      } else if (kind === "backfill") {
        const payload = await callAdminApi(user, "/api/admin/backfill-user-public")
        setNotice({ tone: "ok", text: t("syncedUsernames", { count: Number(payload.written ?? 0) }) })
      } else {
        const payload = await callAdminApi(user, "/api/admin/update-android-config")
        setNotice({ tone: "ok", text: t("androidConfigSynced", { versionName: String(payload.latestVersionName), versionCode: String(payload.latestVersionCode) }) })
      }
      setOverview(await loadOverview())
    } catch (err) {
      setNotice({ tone: "error", text: apiError(err) })
    } finally {
      setBusy("")
    }
  }

  const lastSeenFmt = new Intl.DateTimeFormat(locale, { day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit" })

  return (
    <AdminShell user={user}>
      {state === "loading" ? (
        <div className="space-y-6">
          <Skeleton className="h-7 w-48" />
          <Skeleton className="h-24 w-full" />
          <Skeleton className="h-72 w-full" />
        </div>
      ) : state === "denied" ? (
        <Section><EmptyState title={t("noPermission")} /></Section>
      ) : (
        <div className="space-y-6">
          <PageHeader title={t("dashboardTitle")} description={t("dashboardDesc")} />
          <div className="-mt-2 flex flex-wrap gap-2">
                <button type="button" onClick={() => run("invites")} disabled={busy !== ""} className="auth-btn-secondary !h-9 !w-auto px-3">
                  {busy === "invites" ? t("processing") : t("syncInvites")}
                </button>
                <button type="button" onClick={() => run("config")} disabled={busy !== ""} className="auth-btn-secondary !h-9 !w-auto px-3">
                  {busy === "config" ? t("processing") : t("syncAndroidConfig")}
                </button>
                <button type="button" onClick={() => run("backfill")} disabled={busy !== ""} className="auth-btn-primary !h-9 !w-auto px-3">
                  {busy === "backfill" ? t("processing") : t("syncLegacyUsers")}
                </button>
          </div>

          {notice && <p className={`auth-notice ${notice.tone === "ok" ? "auth-notice-ok" : "auth-notice-error"}`}>{notice.text}</p>}

          {overview && (
            <>
              <div className="grid grid-cols-2 gap-px overflow-hidden rounded-lg border lg:grid-cols-5 [&>*:last-child]:col-span-2 lg:[&>*:last-child]:col-span-1" style={{ borderColor: "var(--border)", backgroundColor: "var(--border)" }}>
                <Count label={t("totalUsers")} value={overview.totalUsers} note={t("registeredAccounts")} />
                <Count label={t("onlineNow")} value={overview.onlineUsers} note={t("activeIn2Minutes")} />
                <Count label={t("activeToday")} value={overview.activeToday} note={t("active24Hours")} />
                <Count label={t("needsUpdate")} value={overview.outdatedUsers} note={t("oldAndroidVersion")} warn={overview.outdatedUsers > 0} />
                <Count label={t("latestAndroid")} text={`v${overview.latestVersionName}+${overview.latestVersionCode}`} note={`${t("webVersion")} v${APP_VERSION_NAME}+${APP_VERSION_CODE}`} />
              </div>

              <Section title={t("growthTitle")} aside={
                <span className="flex gap-3">
                  <span className="flex items-center gap-1.5"><span className="h-2 w-2 rounded-sm" style={{ backgroundColor: "var(--primary)" }} />{t("newUsers")}</span>
                  <span className="flex items-center gap-1.5"><span className="h-2 w-2 rounded-sm" style={{ backgroundColor: "var(--text-muted)" }} />{t("activeUsers")}</span>
                </span>
              }>
                <div className="h-56 w-full min-w-0">
                  <ResponsiveContainer width="100%" height="100%" initialDimension={{ width: 320, height: 224 }}>
                    <BarChart data={overview.growth} barGap={2} margin={{ top: 4, right: 4, bottom: 0, left: 0 }}>
                      <CartesianGrid vertical={false} stroke="var(--border)" />
                      <XAxis dataKey="day" tickLine={false} axisLine={false} tick={{ fontSize: 11, fill: "var(--text-muted)" }} />
                      <YAxis width={28} allowDecimals={false} tickLine={false} axisLine={false} tick={{ fontSize: 11, fill: "var(--text-muted)" }} />
                      <Tooltip cursor={{ fill: "var(--surface-soft)" }} contentStyle={{ backgroundColor: "var(--bg-card)", border: "1px solid var(--border)", borderRadius: 6, fontSize: 12 }} />
                      <Bar dataKey="users" name={t("newUsers")} fill="var(--primary)" radius={[3, 3, 0, 0]} maxBarSize={14} isAnimationActive={false} />
                      <Bar dataKey="active" name={t("activeUsers")} fill="var(--text-muted)" fillOpacity={0.5} radius={[3, 3, 0, 0]} maxBarSize={14} isAnimationActive={false} />
                    </BarChart>
                  </ResponsiveContainer>
                </div>
              </Section>

              <div id="users" className="scroll-mt-20">
                <Section title={t("userMonitoring")} aside={t("privacyNote")} flush>
                  <div className="flex flex-col gap-3 border-b px-5 py-3 lg:flex-row lg:items-center lg:justify-between" style={{ borderColor: "var(--border)" }}>
                    <div className="relative lg:w-72">
                      <Search size={15} className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2" style={{ color: "var(--text-muted)" }} />
                      <input type="search" value={search} onChange={(e) => setSearch(e.target.value)} placeholder={t("searchPlaceholder")} aria-label={t("searchPlaceholder")} className="field w-full pl-9" />
                    </div>
                    <div className="seg" role="group">
                      {(["all", "online", "android", "web", "outdated"] as Filter[]).map((f) => (
                        <button key={f} type="button" aria-pressed={filter === f} onClick={() => setFilter(f)}>{f === "outdated" ? t("needsUpdate") : t(f)}</button>
                      ))}
                    </div>
                  </div>
                  {users.length === 0 ? (
                    <EmptyState title={t("noUsersMatch")} />
                  ) : (
                    <div className="overflow-x-auto">
                      <table className="w-full min-w-[640px] text-sm">
                        <thead>
                          <tr className="border-b text-left text-xs uppercase tracking-[0.06em]" style={{ borderColor: "var(--border)", color: "var(--text-muted)" }}>
                            <th className="px-5 py-2.5 font-medium">{t("user")}</th>
                            <th className="px-3 py-2.5 font-medium">{t("status")}</th>
                            <th className="px-3 py-2.5 font-medium">{t("source")}</th>
                            <th className="px-3 py-2.5 font-medium">{t("version")}</th>
                            <th className="px-5 py-2.5 text-right font-medium">{t("lastSeen")}</th>
                          </tr>
                        </thead>
                        <tbody>
                          {users.map((u) => (
                            <tr key={u.id} className="data-row border-b last:border-b-0" style={{ borderColor: "var(--border)" }}>
                              <td className="px-5 py-3">
                                <p style={{ color: "var(--text-primary)" }}>{u.name}</p>
                                <p className="text-xs" style={{ color: "var(--text-muted)" }}>{u.devicesCount} {t("device")}</p>
                              </td>
                              <td className="px-3 py-3">
                                <span className="flex items-center gap-1.5 text-xs" style={{ color: u.online ? "var(--income)" : "var(--text-muted)" }}>
                                  <span className="h-1.5 w-1.5 rounded-full" style={{ backgroundColor: "currentColor" }} />
                                  {u.online ? t("online") : t("offline")}
                                </span>
                              </td>
                              <td className="px-3 py-3">
                                <p className="capitalize" style={{ color: "var(--text-primary)" }}>{u.latestSource === "unknown" ? t("unknown") : u.latestSource}</p>
                                <p className="text-xs" style={{ color: "var(--text-muted)" }}>{u.latestDeviceName}</p>
                              </td>
                              <td className="px-3 py-3 tabular-nums" style={{ color: "var(--text-secondary)" }}>
                                {u.appVersionLabel} {u.outdated && <Pill tone="warning">{t("updateRequired")}</Pill>}
                              </td>
                              <td className="whitespace-nowrap px-5 py-3 text-right text-xs tabular-nums" style={{ color: "var(--text-muted)" }}>
                                {u.lastSeenAt ? lastSeenFmt.format(new Date(u.lastSeenAt)) : t("never")}
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  )}
                </Section>
              </div>

              <div id="versions" className="scroll-mt-20">
                <Section title={t("versionDistribution")} aside={t("activeDevicesCount", { count: overview.activeDevices })} flush>
                  {overview.versions.length === 0 ? (
                    <EmptyState title={t("noVersions")} />
                  ) : (
                    <ul>
                      {overview.versions.map((v) => {
                        const share = overview.totalUsers > 0 ? (v.value / overview.totalUsers) * 100 : 0
                        return (
                          <li key={v.name} className="flex items-center gap-4 border-b px-5 py-3 last:border-b-0" style={{ borderColor: "var(--border)" }}>
                            <span className="w-28 shrink-0 text-sm tabular-nums" style={{ color: "var(--text-primary)" }}>{v.name}</span>
                            <div className="h-1.5 flex-1 overflow-hidden rounded-full" style={{ backgroundColor: "var(--surface-soft)" }}>
                              <div className="h-full rounded-full" style={{ width: `${share}%`, backgroundColor: "var(--primary)" }} />
                            </div>
                            <span className="w-24 text-right text-xs tabular-nums" style={{ color: "var(--text-muted)" }}>{v.value} {t("usersLabel")}</span>
                          </li>
                        )
                      })}
                    </ul>
                  )}
                </Section>
              </div>
            </>
          )}
        </div>
      )}
    </AdminShell>
  )
}

function Count({ label, value, text, note, warn = false }: { label: string; value?: number; text?: string; note: string; warn?: boolean }) {
  return (
    <div className="px-5 py-4" style={{ backgroundColor: "var(--bg-card)" }}>
      <p className="text-xs font-medium uppercase tracking-[0.08em]" style={{ color: "var(--text-muted)" }}>{label}</p>
      <p className="mt-2 text-2xl font-semibold tabular-nums" style={{ color: warn ? "var(--warning)" : "var(--text-primary)" }}>{text ?? value}</p>
      <p className="mt-1 text-xs" style={{ color: "var(--text-muted)" }}>{note}</p>
    </div>
  )
}

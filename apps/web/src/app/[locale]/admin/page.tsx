"use client"

import { Fragment, useCallback, useEffect, useState, type FormEvent } from "react"
import { needsEmailVerification } from "@/lib/auth-verify"
import { onAuthStateChanged, type User } from "firebase/auth"
import { doc, getDoc } from "firebase/firestore"
import { ChevronDown, ChevronRight, Search } from "lucide-react"
import { useLocale, useTranslations } from "next-intl"
import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts"

import AdminDialog from "@/components/AdminDialog"
import AdminShell from "@/components/AdminShell"
import { EmptyState, PageHeader, Pill, Section, Skeleton } from "@/components/ui"
import type { AdminFilter, AdminOverview, AdminUser, OverviewQuery } from "@/lib/admin-types"
import { auth, db } from "@/lib/firebase"
import { useRouter } from "@/lib/i18n"
import { startWebPresence, writeWebPresence } from "@/lib/web-presence"

type AuditEntry = {
  id: string
  action: string
  actorUid: string
  actorName: string | null
  targetUid: string
  targetName: string | null
  at: number | null
  details: Record<string, string | number>
}

type Dialog =
  | { kind: "reset"; user: AdminUser }
  | { kind: "status"; user: AdminUser }
  | { kind: "config" }
  | null

const PAGE_SIZE = 25
const FILTERS: AdminFilter[] = ["all", "online", "android", "web", "outdated", "disabled"]
const AUDIT_ACTIONS = ["reset_password", "disable_user", "enable_user", "android_config", "account_deleted"]

/** Calls an admin route with the caller's ID token; errors carry the API's stable code. */
async function adminFetch<T>(user: User, path: string, body?: Record<string, unknown>): Promise<T> {
  const token = await user.getIdToken()
  const res = await fetch(path, {
    method: body ? "POST" : "GET",
    headers: { authorization: `Bearer ${token}`, ...(body ? { "content-type": "application/json" } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  })
  const payload = (res.headers.get("content-type") ?? "").includes("application/json") ? await res.json() : {}
  if (!res.ok) throw new Error(typeof payload.code === "string" ? payload.code : "server")
  return payload as T
}

function isStrongPassword(value: string) {
  return value.length >= 8 && value.length <= 128 && /[A-Za-z]/.test(value) && /\d/.test(value)
}

function useRelativeTime(locale: string) {
  const rtf = new Intl.RelativeTimeFormat(locale, { numeric: "auto" })
  return (ms: number) => {
    const minutes = Math.round((ms - Date.now()) / 60_000)
    if (Math.abs(minutes) < 60) return rtf.format(minutes, "minute")
    const hours = Math.round(minutes / 60)
    if (Math.abs(hours) < 48) return rtf.format(hours, "hour")
    return rtf.format(Math.round(hours / 24), "day")
  }
}

export default function AdminPage() {
  const t = useTranslations("admin")
  const tApi = useTranslations("apiErrors")
  const locale = useLocale()
  const apiError = useCallback(
    (err: unknown) => {
      const code = err instanceof Error ? err.message : "server"
      return tApi.has(code) ? tApi(code) : tApi("server")
    },
    [tApi],
  )
  const router = useRouter()
  const [user, setUser] = useState<User | null>(null)
  const [demo, setDemo] = useState(false)
  const [state, setState] = useState<"loading" | "denied" | "ready">("loading")
  const [overview, setOverview] = useState<AdminOverview | null>(null)
  const [listLoading, setListLoading] = useState(false)
  const [notice, setNotice] = useState<{ tone: "ok" | "error"; text: string } | null>(null)
  const [searchInput, setSearchInput] = useState("")
  const [query, setQuery] = useState<OverviewQuery>({ page: 1, q: "", filter: "all" })
  const [expanded, setExpanded] = useState<string | null>(null)
  const [busy, setBusy] = useState<"" | "backfill" | "invites">("")
  const [dialog, setDialog] = useState<Dialog>(null)
  const [audit, setAudit] = useState<{ entries: AuditEntry[]; next: number | null; loading: boolean; failed: boolean }>({ entries: [], next: null, loading: false, failed: false })
  const [reloadKey, setReloadKey] = useState(0)

  useEffect(() => {
    let stopPresence: (() => void) | undefined
    const unsub = onAuthStateChanged(auth, async (u) => {
      stopPresence?.()
      if (!u) {
        router.replace("/login")
        return
      }
      if (needsEmailVerification(u)) {
        router.replace("/login?verify=1")
        return
      }
      setUser(u)
      // Development-only layout review with sample data; dropped from production builds.
      if (process.env.NODE_ENV === "development" && new URLSearchParams(window.location.search).get("demo") === "1") {
        setDemo(true)
        setState("ready")
        return
      }
      const snap = await getDoc(doc(db, "users", u.uid)).catch(() => null)
      if (snap?.data()?.systemRole !== "superadmin") {
        setState("denied")
        router.replace("/dashboard")
        return
      }
      // Record this session first so the admin shows up as online in the list.
      await writeWebPresence(u.uid).catch(() => {})
      stopPresence = startWebPresence(u.uid)
      setState("ready")
    })
    return () => {
      stopPresence?.()
      unsub()
    }
  }, [router])

  // Typing settles for a moment before the server is asked again.
  useEffect(() => {
    const id = window.setTimeout(() => {
      setQuery((prev) => (prev.q === searchInput.trim() ? prev : { ...prev, q: searchInput.trim(), page: 1 }))
    }, 300)
    return () => window.clearTimeout(id)
  }, [searchInput])

  // Users, stats and charts come from the server one page at a time.
  useEffect(() => {
    if (state !== "ready" || !user) return
    let cancelled = false
    const load = async () => {
      setListLoading(true)
      try {
        const next = demo
          ? (await import("@/lib/demo-data")).buildDemoAdminOverview(query, PAGE_SIZE)
          : await adminFetch<AdminOverview>(user, `/api/admin/overview?${new URLSearchParams({ page: String(query.page), pageSize: String(PAGE_SIZE), q: query.q, filter: query.filter })}`)
        if (!cancelled) setOverview(next)
      } catch {
        if (!cancelled) setNotice({ tone: "error", text: t("loadFailed") })
      } finally {
        if (!cancelled) setListLoading(false)
      }
    }
    void load()
    return () => {
      cancelled = true
    }
  }, [state, user, demo, query, reloadKey, t])

  const loadAudit = useCallback(
    async (before: number | null) => {
      if (!user || demo) return
      setAudit((a) => ({ ...a, loading: true, failed: false }))
      try {
        const res = await adminFetch<{ entries: AuditEntry[]; next: number | null }>(user, `/api/admin/audit${before ? `?before=${before}` : ""}`)
        setAudit((a) => ({ entries: before ? [...a.entries, ...res.entries] : res.entries, next: res.next, loading: false, failed: false }))
      } catch {
        setAudit((a) => ({ ...a, loading: false, failed: true }))
      }
    },
    [user, demo],
  )

  useEffect(() => {
    if (state !== "ready") return
    const id = window.setTimeout(() => void loadAudit(null), 0)
    return () => window.clearTimeout(id)
  }, [state, loadAudit, reloadKey])

  const refresh = () => setReloadKey((k) => k + 1)

  const run = async (kind: "backfill" | "invites") => {
    if (!user) return
    setBusy(kind)
    setNotice(null)
    try {
      if (kind === "invites") {
        const payload = await adminFetch<{ created?: number }>(user, "/api/admin/backfill-family-invites", {})
        setNotice({ tone: "ok", text: t("invitesSynced", { count: Number(payload.created ?? 0) }) })
      } else {
        const payload = await adminFetch<{ written?: number }>(user, "/api/admin/backfill-user-public", {})
        setNotice({ tone: "ok", text: t("syncedUsernames", { count: Number(payload.written ?? 0) }) })
      }
      refresh()
    } catch (err) {
      setNotice({ tone: "error", text: apiError(err) })
    } finally {
      setBusy("")
    }
  }

  const lastSeenFmt = new Intl.DateTimeFormat(locale, { day: "2-digit", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" })
  const relative = useRelativeTime(locale)
  const stats = overview?.stats
  const pages = overview ? Math.max(1, Math.ceil(overview.total / overview.pageSize)) : 1
  const auditName = (uid: string, name: string | null) => (uid ? name ?? t("audit.deletedUser", { id: uid.slice(0, 6) }) : "—")

  return (
    <AdminShell user={user}>
      {state === "loading" || (state === "ready" && !overview && listLoading) ? (
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
            <button type="button" onClick={() => setDialog({ kind: "config" })} disabled={busy !== "" || !stats} className="auth-btn-secondary !h-9 !w-auto px-3">
              {t("publishAndroid")}
            </button>
            <button type="button" onClick={() => run("backfill")} disabled={busy !== ""} className="auth-btn-primary !h-9 !w-auto px-3">
              {busy === "backfill" ? t("processing") : t("syncLegacyUsers")}
            </button>
          </div>

          {notice && <p role={notice.tone === "error" ? "alert" : "status"} className={`auth-notice ${notice.tone === "ok" ? "auth-notice-ok" : "auth-notice-error"}`}>{notice.text}</p>}

          {overview && stats && (
            <>
              <div className="grid grid-cols-2 gap-px overflow-hidden rounded-lg border lg:grid-cols-5 [&>*:last-child]:col-span-2 lg:[&>*:last-child]:col-span-1" style={{ borderColor: "var(--border)", backgroundColor: "var(--border)" }}>
                <Count label={t("totalUsers")} value={stats.totalUsers} note={t("familiesCount", { count: stats.totalFamilies })} />
                <Count label={t("onlineNow")} value={stats.onlineUsers} note={t("activeIn2Minutes")} />
                <Count label={t("activeToday")} value={stats.activeToday} note={t("active24Hours")} />
                <Count label={t("needsUpdate")} value={stats.outdatedUsers} note={t("oldAndroidVersion")} warn={stats.outdatedUsers > 0} />
                <Count label={t("latestAndroid")} text={`v${stats.latestVersionName}+${stats.latestVersionCode}`} note={`${t("webVersion")} v${stats.webVersionName}+${stats.webVersionCode}`} />
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
                      <input type="search" value={searchInput} onChange={(e) => setSearchInput(e.target.value)} placeholder={t("searchPlaceholder")} aria-label={t("searchPlaceholder")} className="field w-full pl-9" />
                    </div>
                    <div className="seg flex-wrap" role="group" aria-label={t("status")}>
                      {FILTERS.map((f) => (
                        <button key={f} type="button" aria-pressed={query.filter === f} onClick={() => setQuery((q) => ({ ...q, filter: f, page: 1 }))}>
                          {f === "outdated" ? t("needsUpdate") : f === "disabled" ? t("disabledFilter") : t(f)}
                        </button>
                      ))}
                    </div>
                  </div>
                  {overview.users.length === 0 ? (
                    <EmptyState title={t("noUsersMatch")} />
                  ) : (
                    <div className="overflow-x-auto" aria-busy={listLoading}>
                      <table className="w-full min-w-[760px] text-sm" style={{ opacity: listLoading ? 0.6 : 1 }}>
                        <thead>
                          <tr className="border-b text-left text-xs uppercase tracking-[0.06em]" style={{ borderColor: "var(--border)", color: "var(--text-muted)" }}>
                            <th className="px-5 py-2.5 font-medium">{t("user")}</th>
                            <th className="px-3 py-2.5 font-medium">{t("status")}</th>
                            <th className="px-3 py-2.5 font-medium">{t("source")}</th>
                            <th className="px-3 py-2.5 font-medium">{t("version")}</th>
                            <th className="px-3 py-2.5 text-right font-medium">{t("lastSeen")}</th>
                            <th className="px-5 py-2.5 text-right font-medium">{t("actions")}</th>
                          </tr>
                        </thead>
                        <tbody>
                          {overview.users.map((u) => {
                            const open = expanded === u.id
                            const protectedUser = u.role === "superadmin" || u.id === user?.uid
                            return (
                              <Fragment key={u.id}>
                                <tr className="data-row border-b" style={{ borderColor: "var(--border)" }}>
                                  <td className="px-5 py-3">
                                    <button
                                      type="button"
                                      onClick={() => setExpanded(open ? null : u.id)}
                                      aria-expanded={open}
                                      aria-controls={`devices-${u.id}`}
                                      className="flex items-start gap-1.5 text-left"
                                    >
                                      {open ? <ChevronDown size={14} className="mt-0.5 shrink-0" /> : <ChevronRight size={14} className="mt-0.5 shrink-0" />}
                                      <span>
                                        <span className="block" style={{ color: "var(--text-primary)" }}>{u.name}</span>
                                        <span className="block text-xs" style={{ color: "var(--text-muted)" }}>{t("devicesCount", { count: u.devices.length })}</span>
                                      </span>
                                    </button>
                                  </td>
                                  <td className="px-3 py-3">
                                    <span className="flex flex-wrap items-center gap-1.5 text-xs" style={{ color: u.online ? "var(--income)" : "var(--text-muted)" }}>
                                      <span className="h-1.5 w-1.5 rounded-full" style={{ backgroundColor: "currentColor" }} />
                                      {u.online ? t("online") : t("offline")}
                                      {u.disabled && <Pill tone="expense">{t("disabled")}</Pill>}
                                      {u.role === "superadmin" && <Pill>{t("superadmin")}</Pill>}
                                    </span>
                                  </td>
                                  <td className="px-3 py-3">
                                    <p className="flex items-center gap-1.5 capitalize" style={{ color: "var(--text-primary)" }}>
                                      {u.latestSource === "unknown" ? t("unknown") : u.latestSource}
                                      {u.hasWeb && u.latestSource !== "web" && <Pill>{t("web")}</Pill>}
                                    </p>
                                  </td>
                                  <td className="px-3 py-3 tabular-nums" style={{ color: "var(--text-secondary)" }}>
                                    {u.appVersionLabel} {u.outdated && <Pill tone="warning">{t("updateRequired")}</Pill>}
                                  </td>
                                  <td className="whitespace-nowrap px-3 py-3 text-right text-xs tabular-nums" style={{ color: "var(--text-muted)" }}>
                                    {u.lastSeenAt ? <span title={lastSeenFmt.format(new Date(u.lastSeenAt))}>{relative(u.lastSeenAt)}</span> : t("never")}
                                  </td>
                                  <td className="whitespace-nowrap px-5 py-3 text-right">
                                    {protectedUser ? (
                                      <span className="text-xs" style={{ color: "var(--text-muted)" }}>—</span>
                                    ) : (
                                      <span className="inline-flex gap-3 text-xs font-medium">
                                        <button type="button" onClick={() => setDialog({ kind: "reset", user: u })} style={{ color: "var(--primary)" }}>{t("resetPassword")}</button>
                                        <button type="button" onClick={() => setDialog({ kind: "status", user: u })} style={{ color: u.disabled ? "var(--income)" : "var(--expense)" }}>
                                          {u.disabled ? t("enable") : t("disable")}
                                        </button>
                                      </span>
                                    )}
                                  </td>
                                </tr>
                                {open && (
                                  <tr id={`devices-${u.id}`} className="border-b" style={{ borderColor: "var(--border)", backgroundColor: "var(--surface-soft)" }}>
                                    <td colSpan={6} className="px-5 py-3">
                                      {u.devices.length === 0 ? (
                                        <p className="text-xs" style={{ color: "var(--text-muted)" }}>{t("noDevices")}</p>
                                      ) : (
                                        <ul className="space-y-2">
                                          {u.devices.map((d) => (
                                            <li key={d.id} className="grid gap-1 text-xs sm:grid-cols-[1.4fr_1fr_1fr_1.4fr] sm:gap-4">
                                              <span style={{ color: "var(--text-primary)" }}>
                                                {[d.brand, d.model].filter(Boolean).join(" ") || t("unknown")}{" "}
                                                {d.platform === "web" ? <Pill>{t("web")}</Pill> : <span className="capitalize" style={{ color: "var(--text-muted)" }}>· {d.platform}</span>}
                                              </span>
                                              <span style={{ color: "var(--text-secondary)" }}>
                                                {d.platform === "web" ? t("browserSession") : t("androidVersion", { version: d.osVersion || "?" })}
                                              </span>
                                              <span className="tabular-nums" style={{ color: "var(--text-secondary)" }}>
                                                {t("appVersion", { name: d.appVersionName || "-", code: d.appVersionCode ?? "-" })}
                                              </span>
                                              <span className="tabular-nums" style={{ color: "var(--text-muted)" }}>
                                                {d.lastSeenAt ? `${relative(d.lastSeenAt)} · ${lastSeenFmt.format(new Date(d.lastSeenAt))}` : t("never")}
                                              </span>
                                            </li>
                                          ))}
                                        </ul>
                                      )}
                                    </td>
                                  </tr>
                                )}
                              </Fragment>
                            )
                          })}
                        </tbody>
                      </table>
                    </div>
                  )}
                  <div className="flex items-center justify-between gap-3 border-t px-5 py-3 text-xs" style={{ borderColor: "var(--border)", color: "var(--text-muted)" }}>
                    <span>{t("pageOf", { page: overview.page, pages, total: overview.total })}</span>
                    <span className="flex gap-2">
                      <button type="button" disabled={overview.page <= 1 || listLoading} onClick={() => setQuery((q) => ({ ...q, page: q.page - 1 }))} className="auth-btn-secondary !h-8 !w-auto px-3 text-xs">{t("prev")}</button>
                      <button type="button" disabled={overview.page >= pages || listLoading} onClick={() => setQuery((q) => ({ ...q, page: q.page + 1 }))} className="auth-btn-secondary !h-8 !w-auto px-3 text-xs">{t("next")}</button>
                    </span>
                  </div>
                </Section>
              </div>

              <div id="versions" className="scroll-mt-20">
                <Section title={t("versionDistribution")} aside={t("activeDevicesCount", { count: stats.activeDevices })} flush>
                  {overview.versions.length === 0 ? (
                    <EmptyState title={t("noVersions")} />
                  ) : (
                    <ul>
                      {overview.versions.map((v) => {
                        const share = stats.totalUsers > 0 ? (v.value / stats.totalUsers) * 100 : 0
                        return (
                          <li key={v.name} className="flex items-center gap-4 border-b px-5 py-3 last:border-b-0" style={{ borderColor: "var(--border)" }}>
                            <span className="w-28 shrink-0 text-sm tabular-nums" style={{ color: "var(--text-primary)" }}>{v.name}</span>
                            <div className="h-1.5 flex-1 overflow-hidden rounded-full" style={{ backgroundColor: "var(--surface-soft)" }} aria-hidden="true">
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

              <div id="audit" className="scroll-mt-20">
                <Section title={t("audit.title")} aside={t("audit.desc")} flush>
                  {audit.failed ? (
                    <EmptyState title={t("audit.loadFailed")} />
                  ) : audit.entries.length === 0 ? (
                    audit.loading ? <div className="space-y-3 p-5"><Skeleton className="h-6 w-full" /><Skeleton className="h-6 w-full" /></div> : <EmptyState title={t("audit.empty")} />
                  ) : (
                    <ul>
                      {audit.entries.map((e) => (
                        <li key={e.id} className="flex flex-col gap-0.5 border-b px-5 py-3 text-sm last:border-b-0 sm:flex-row sm:items-baseline sm:justify-between sm:gap-4" style={{ borderColor: "var(--border)" }}>
                          <span style={{ color: "var(--text-primary)" }}>
                            {AUDIT_ACTIONS.includes(e.action) ? t(`audit.actions.${e.action}`) : e.action}
                            {e.action === "android_config" && e.details.versionName !== undefined && (
                              <span className="tabular-nums" style={{ color: "var(--text-secondary)" }}> v{e.details.versionName}+{e.details.versionCode}</span>
                            )}
                            <span className="block text-xs" style={{ color: "var(--text-muted)" }}>
                              {t("audit.by", { actor: auditName(e.actorUid, e.actorName) })}
                              {e.targetUid && e.targetUid !== e.actorUid ? ` · ${t("audit.target", { target: auditName(e.targetUid, e.targetName) })}` : ""}
                            </span>
                          </span>
                          <span className="shrink-0 text-xs tabular-nums" style={{ color: "var(--text-muted)" }}>{e.at ? lastSeenFmt.format(new Date(e.at)) : "—"}</span>
                        </li>
                      ))}
                    </ul>
                  )}
                  {audit.next && (
                    <div className="border-t p-3 text-center" style={{ borderColor: "var(--border)" }}>
                      <button type="button" disabled={audit.loading} onClick={() => void loadAudit(audit.next)} className="text-sm font-medium" style={{ color: "var(--primary)" }}>
                        {audit.loading ? t("processing") : t("audit.older")}
                      </button>
                    </div>
                  )}
                </Section>
              </div>
            </>
          )}
        </div>
      )}

      {dialog?.kind === "reset" && user && (
        <ResetPasswordDialog
          target={dialog.user}
          onClose={() => setDialog(null)}
          onSubmit={async (password) => {
            await adminFetch(user, "/api/admin/reset-password", { uid: dialog.user.id, newPassword: password })
            setNotice({ tone: "ok", text: t("passwordReset", { name: dialog.user.name }) })
            refresh()
          }}
          apiError={apiError}
        />
      )}
      {dialog?.kind === "status" && user && (
        <StatusDialog
          target={dialog.user}
          onClose={() => setDialog(null)}
          onSubmit={async () => {
            const disabled = !dialog.user.disabled
            await adminFetch(user, "/api/admin/user-status", { uid: dialog.user.id, disabled })
            setNotice({ tone: "ok", text: disabled ? t("userDisabled", { name: dialog.user.name }) : t("userEnabled", { name: dialog.user.name }) })
            refresh()
          }}
          apiError={apiError}
        />
      )}
      {dialog?.kind === "config" && user && stats && (
        <AndroidConfigDialog
          current={{ name: stats.latestVersionName, code: stats.latestVersionCode }}
          onClose={() => setDialog(null)}
          onSubmit={async (versionName, versionCode) => {
            const payload = await adminFetch<{ latestVersionName: string; latestVersionCode: number }>(user, "/api/admin/update-android-config", { versionName, versionCode })
            setNotice({ tone: "ok", text: t("androidConfigSynced", { versionName: payload.latestVersionName, versionCode: String(payload.latestVersionCode) }) })
            refresh()
          }}
          apiError={apiError}
        />
      )}
    </AdminShell>
  )
}

type DialogProps = { onClose: () => void; apiError: (err: unknown) => string }

/** Shared submit handling: busy state, inline error, close on success. */
function useDialogSubmit(onClose: () => void, apiError: (err: unknown) => string) {
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState("")
  const submit = async (action: () => Promise<void>) => {
    setBusy(true)
    setError("")
    try {
      await action()
      onClose()
    } catch (err) {
      setError(apiError(err))
      setBusy(false)
    }
  }
  return { busy, error, setError, submit }
}

function DialogActions({ busy, confirmLabel, disabled = false, danger = false, onClose }: { busy: boolean; confirmLabel: string; disabled?: boolean; danger?: boolean; onClose: () => void }) {
  const t = useTranslations("admin")
  const tCommon = useTranslations("common")
  return (
    <div className="flex justify-end gap-2">
      <button type="button" onClick={onClose} disabled={busy} className="auth-btn-secondary !h-9 !w-auto px-3">{tCommon("cancel")}</button>
      <button
        type="submit"
        disabled={busy || disabled}
        className={`${danger ? "" : "auth-btn-primary"} flex !h-9 !w-auto items-center rounded-md px-3 text-sm font-semibold disabled:cursor-not-allowed disabled:opacity-60`}
        style={danger ? { backgroundColor: "var(--expense)", color: "var(--bg-card)" } : undefined}
      >
        {busy ? t("processing") : confirmLabel}
      </button>
    </div>
  )
}

function ResetPasswordDialog({ target, onSubmit, onClose, apiError }: DialogProps & { target: AdminUser; onSubmit: (password: string) => Promise<void> }) {
  const t = useTranslations("admin")
  const tAuth = useTranslations("auth")
  const [password, setPassword] = useState("")
  const [confirmed, setConfirmed] = useState(false)
  const { busy, error, submit } = useDialogSubmit(onClose, apiError)
  const valid = isStrongPassword(password)

  const onForm = (e: FormEvent) => {
    e.preventDefault()
    if (valid && confirmed) void submit(() => onSubmit(password))
  }

  return (
    <AdminDialog title={t("resetTitle", { name: target.name })} onClose={onClose} busy={busy}>
      <form onSubmit={onForm} className="space-y-4">
        <p className="text-sm leading-6" style={{ color: "var(--text-secondary)" }}>{t("resetExplain")}</p>
        <div>
          <label htmlFor="admin-new-password" className="mb-1 block text-xs font-medium" style={{ color: "var(--text-secondary)" }}>{t("newPassword")}</label>
          <input id="admin-new-password" type="text" value={password} onChange={(e) => setPassword(e.target.value)} autoComplete="off" spellCheck={false} className="field w-full" />
          <p className="mt-1 text-xs" style={{ color: password && !valid ? "var(--expense)" : "var(--text-muted)" }}>{tAuth("passwordHint")}</p>
        </div>
        <label className="flex items-start gap-2 text-sm" style={{ color: "var(--text-secondary)" }}>
          <input type="checkbox" checked={confirmed} onChange={(e) => setConfirmed(e.target.checked)} className="mt-1" />
          {t("resetConfirm", { name: target.name })}
        </label>
        {error && <p role="alert" className="auth-notice auth-notice-error">{error}</p>}
        <DialogActions busy={busy} confirmLabel={t("resetPassword")} disabled={!valid || !confirmed} onClose={onClose} />
      </form>
    </AdminDialog>
  )
}

function StatusDialog({ target, onSubmit, onClose, apiError }: DialogProps & { target: AdminUser; onSubmit: () => Promise<void> }) {
  const t = useTranslations("admin")
  const { busy, error, submit } = useDialogSubmit(onClose, apiError)
  const disabling = !target.disabled
  return (
    <AdminDialog title={disabling ? t("disableTitle", { name: target.name }) : t("enableTitle", { name: target.name })} onClose={onClose} busy={busy}>
      <form
        onSubmit={(e) => {
          e.preventDefault()
          void submit(onSubmit)
        }}
        className="space-y-4"
      >
        <p className="text-sm leading-6" style={{ color: "var(--text-secondary)" }}>{disabling ? t("disableExplain") : t("enableExplain")}</p>
        {error && <p role="alert" className="auth-notice auth-notice-error">{error}</p>}
        <DialogActions busy={busy} confirmLabel={disabling ? t("disable") : t("enable")} danger={disabling} onClose={onClose} />
      </form>
    </AdminDialog>
  )
}

function AndroidConfigDialog({ current, onSubmit, onClose, apiError }: DialogProps & { current: { name: string; code: number }; onSubmit: (name: string, code: number) => Promise<void> }) {
  const t = useTranslations("admin")
  const tApi = useTranslations("apiErrors")
  const [name, setName] = useState("")
  const [code, setCode] = useState("")
  const { busy, error, setError, submit } = useDialogSubmit(onClose, apiError)

  const onForm = (e: FormEvent) => {
    e.preventDefault()
    const versionCode = Number(code)
    // Same checks as the server, so typos are caught before the request.
    if (!/^\d{1,4}\.\d{1,4}\.\d{1,4}$/.test(name.trim())) return setError(tApi("invalidVersionName"))
    if (!/^\d+$/.test(code.trim()) || versionCode < 1) return setError(tApi("invalidVersionCode"))
    if (versionCode < current.code) return setError(tApi("versionCodeLower"))
    void submit(() => onSubmit(name.trim(), versionCode))
  }

  return (
    <AdminDialog title={t("publishAndroid")} onClose={onClose} busy={busy}>
      <form onSubmit={onForm} className="space-y-4">
        <p className="text-sm leading-6" style={{ color: "var(--text-secondary)" }}>{t("publishExplain", { current: `v${current.name}+${current.code}` })}</p>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label htmlFor="android-version-name" className="mb-1 block text-xs font-medium" style={{ color: "var(--text-secondary)" }}>{t("versionName")}</label>
            <input id="android-version-name" value={name} onChange={(e) => setName(e.target.value)} placeholder="1.2.3" autoComplete="off" spellCheck={false} className="field w-full tabular-nums" />
          </div>
          <div>
            <label htmlFor="android-version-code" className="mb-1 block text-xs font-medium" style={{ color: "var(--text-secondary)" }}>{t("versionCode")}</label>
            <input id="android-version-code" value={code} onChange={(e) => setCode(e.target.value)} inputMode="numeric" placeholder={String(current.code + 1)} autoComplete="off" className="field w-full tabular-nums" />
          </div>
        </div>
        {error && <p role="alert" className="auth-notice auth-notice-error">{error}</p>}
        <DialogActions busy={busy} confirmLabel={t("publish")} disabled={!name || !code} onClose={onClose} />
      </form>
    </AdminDialog>
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

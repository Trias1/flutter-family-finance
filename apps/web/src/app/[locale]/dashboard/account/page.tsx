"use client"

import { useState, type FormEvent, type ReactNode } from "react"
import {
  EmailAuthProvider,
  GoogleAuthProvider,
  reauthenticateWithCredential,
  reauthenticateWithPopup,
  sendPasswordResetEmail,
  updatePassword,
  type User,
} from "firebase/auth"
import { useLocale, useTranslations } from "next-intl"

import { EmptyState, PageHeader, Pill, Section, Skeleton } from "@/components/ui"
import { useFamilyData } from "@/lib/family-data"
import { auth, signOutAndClear } from "@/lib/firebase"

// Same rule as sign-up on the login page and the admin reset route.
function isStrongPassword(value: string) {
  return value.length >= 8 && /[A-Za-z]/.test(value) && /\d/.test(value)
}

function errorCode(error: unknown) {
  return typeof error === "object" && error !== null && "code" in error ? String((error as { code?: unknown }).code) : ""
}

type Notice = { tone: "ok" | "error"; text: string } | null

function NoticeLine({ notice }: { notice: Notice }) {
  if (!notice) return null
  return <p role={notice.tone === "error" ? "alert" : "status"} className={`auth-notice ${notice.tone === "ok" ? "auth-notice-ok" : "auth-notice-error"}`}>{notice.text}</p>
}

function Row({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex flex-col gap-0.5 sm:flex-row sm:items-baseline sm:justify-between sm:gap-6">
      <dt className="text-sm" style={{ color: "var(--text-secondary)" }}>{label}</dt>
      <dd className="min-w-0 truncate text-sm" style={{ color: "var(--text-primary)" }}>{children}</dd>
    </div>
  )
}

function Field({ id, label, value, onChange, autoComplete, hint }: { id: string; label: string; value: string; onChange: (v: string) => void; autoComplete: string; hint?: string }) {
  return (
    <div>
      <label htmlFor={id} className="mb-1 block text-xs font-medium" style={{ color: "var(--text-secondary)" }}>{label}</label>
      <input id={id} type="password" value={value} onChange={(e) => onChange(e.target.value)} autoComplete={autoComplete} className="field w-full" />
      {hint && <p className="mt-1 text-xs" style={{ color: "var(--text-muted)" }}>{hint}</p>}
    </div>
  )
}

export default function AccountPage() {
  const t = useTranslations("dash.account")
  const tAuth = useTranslations("auth")
  const tApi = useTranslations("apiErrors")
  const data = useFamilyData()
  // DashboardShell renders pages only once someone is signed in.
  const user = auth.currentUser

  if (!user || !data.ready) {
    return (
      <div className="space-y-6">
        <Skeleton className="h-7 w-48" />
        <Skeleton className="h-40 w-full" />
        <Skeleton className="h-56 w-full" />
      </div>
    )
  }

  const providers = user.providerData.map((p) => p.providerId)
  const hasPassword = providers.includes("password")
  const hasGoogle = providers.includes("google.com")
  const methods = [hasPassword ? t("methodPassword") : null, hasGoogle ? t("methodGoogle") : null].filter(Boolean).join(", ") || t("methodOther")

  // Firebase errors become short, friendly messages; unknown ones stay generic.
  const authMessage = (error: unknown) => {
    const code = errorCode(error)
    if (code.includes("wrong-password") || code.includes("invalid-credential") || code.includes("invalid-login-credentials")) return t("errors.wrongPassword")
    if (code.includes("too-many-requests")) return tAuth("errors.tooMany")
    if (code.includes("network-request-failed")) return tAuth("errors.network")
    if (code.includes("weak-password") || code.includes("password-does-not-meet-requirements")) return tAuth("errors.weakPassword")
    if (code.includes("user-mismatch")) return t("errors.userMismatch")
    if (code.includes("popup-closed-by-user") || code.includes("cancelled-popup-request")) return ""
    if (code.includes("popup-blocked")) return t("errors.popupBlocked")
    return t("errors.generic")
  }

  return (
    <div className="space-y-6">
      <PageHeader title={t("title")} description={t("desc")} />

      <Section title={t("profile")}>
        <dl className="space-y-3">
          <Row label={t("name")}>{data.profileName || user.displayName || "—"}</Row>
          <Row label={t("email")}>{user.email || "—"}</Row>
          <Row label={t("signInMethod")}>{methods}</Row>
          <Row label={t("currency")}>{data.currency}</Row>
        </dl>
        <p className="mt-4 text-xs leading-5" style={{ color: "var(--text-muted)" }}>{t("editInApp")}</p>
      </Section>

      <Section title={t("family")} aside={data.scope === "family" ? t("memberCount", { count: data.members.length }) : undefined} flush>
        {data.scope !== "family" ? (
          <EmptyState title={t("noFamily")} hint={t("noFamilyHint")} />
        ) : (
          <>
            <p className="border-b px-5 py-3 text-sm font-medium" style={{ borderColor: "var(--border)", color: "var(--text-primary)" }}>{data.familyName || "—"}</p>
            <ul>
              {data.members.map((m) => (
                <li key={m.id} className="flex items-center justify-between gap-3 border-b px-5 py-3 text-sm last:border-b-0" style={{ borderColor: "var(--border)" }}>
                  <span className="truncate" style={{ color: "var(--text-primary)" }}>{m.name}</span>
                  <span className="flex shrink-0 gap-1.5">
                    {m.id === user.uid && <Pill>{t("you")}</Pill>}
                    {m.id === data.familyOwnerId && <Pill tone="income">{t("owner")}</Pill>}
                  </span>
                </li>
              ))}
            </ul>
          </>
        )}
      </Section>

      <Section title={t("security")}>
        {hasPassword ? (
          <PasswordForms user={user} authMessage={authMessage} />
        ) : (
          <p className="text-sm" style={{ color: "var(--text-secondary)" }}>{t("googleOnly")}</p>
        )}
      </Section>

      <DeleteAccount user={user} hasPassword={hasPassword} hasGoogle={hasGoogle} isFamily={data.scope === "family"} authMessage={authMessage} apiMessage={(code) => (tApi.has(code) ? tApi(code) : tApi("server"))} />
    </div>
  )
}

function PasswordForms({ user, authMessage }: { user: User; authMessage: (error: unknown) => string }) {
  const t = useTranslations("dash.account")
  const tAuth = useTranslations("auth")
  const [current, setCurrent] = useState("")
  const [next, setNext] = useState("")
  const [repeat, setRepeat] = useState("")
  const [busy, setBusy] = useState<"" | "change" | "reset">("")
  const [notice, setNotice] = useState<Notice>(null)

  const submit = async (e: FormEvent) => {
    e.preventDefault()
    setNotice(null)
    if (!isStrongPassword(next)) return setNotice({ tone: "error", text: tAuth("errors.weakPassword") })
    if (next !== repeat) return setNotice({ tone: "error", text: t("errors.mismatch") })
    if (next === current) return setNotice({ tone: "error", text: t("errors.samePassword") })
    setBusy("change")
    try {
      await reauthenticateWithCredential(user, EmailAuthProvider.credential(user.email ?? "", current))
      await updatePassword(user, next)
      setCurrent("")
      setNext("")
      setRepeat("")
      setNotice({ tone: "ok", text: t("passwordChanged") })
    } catch (error) {
      setNotice({ tone: "error", text: authMessage(error) || t("errors.generic") })
    } finally {
      setBusy("")
    }
  }

  const sendReset = async () => {
    if (!user.email) return
    setNotice(null)
    setBusy("reset")
    try {
      await sendPasswordResetEmail(auth, user.email)
      setNotice({ tone: "ok", text: t("resetSent", { email: user.email }) })
    } catch (error) {
      setNotice({ tone: "error", text: authMessage(error) || t("errors.generic") })
    } finally {
      setBusy("")
    }
  }

  return (
    <div className="space-y-4">
      <form onSubmit={submit} className="grid max-w-md gap-3">
        <h3 className="text-sm font-medium" style={{ color: "var(--text-primary)" }}>{t("changePassword")}</h3>
        <Field id="current-password" label={t("currentPassword")} value={current} onChange={setCurrent} autoComplete="current-password" />
        <Field id="new-password" label={t("newPassword")} value={next} onChange={setNext} autoComplete="new-password" hint={tAuth("passwordHint")} />
        <Field id="repeat-password" label={t("repeatPassword")} value={repeat} onChange={setRepeat} autoComplete="new-password" />
        <button type="submit" disabled={busy !== "" || !current || !next || !repeat} className="auth-btn-primary !h-9 !w-auto justify-self-start px-4">
          {busy === "change" ? t("saving") : t("changePassword")}
        </button>
      </form>
      <div className="border-t pt-4" style={{ borderColor: "var(--border)" }}>
        <p className="text-sm" style={{ color: "var(--text-secondary)" }}>{t("resetHint")}</p>
        <button type="button" onClick={sendReset} disabled={busy !== ""} className="auth-btn-secondary mt-2 !h-9 !w-auto px-4">
          {busy === "reset" ? t("sending") : t("sendReset")}
        </button>
      </div>
      <NoticeLine notice={notice} />
    </div>
  )
}

function DeleteAccount({
  user,
  hasPassword,
  hasGoogle,
  isFamily,
  authMessage,
  apiMessage,
}: {
  user: User
  hasPassword: boolean
  hasGoogle: boolean
  isFamily: boolean
  authMessage: (error: unknown) => string
  apiMessage: (code: string) => string
}) {
  const t = useTranslations("dash.account.delete")
  const tAccount = useTranslations("dash.account")
  const locale = useLocale()
  const [word, setWord] = useState("")
  const [password, setPassword] = useState("")
  const [busy, setBusy] = useState(false)
  const [notice, setNotice] = useState<Notice>(null)
  const confirmWord = t("word")
  const ready = word.trim().toUpperCase() === confirmWord.toUpperCase() && (!hasPassword || password.length > 0)

  const remove = async (e: FormEvent) => {
    e.preventDefault()
    if (!ready) return
    setBusy(true)
    setNotice(null)
    try {
      // The server only accepts a sign-in from the last few minutes.
      if (hasPassword) await reauthenticateWithCredential(user, EmailAuthProvider.credential(user.email ?? "", password))
      else if (hasGoogle) await reauthenticateWithPopup(user, new GoogleAuthProvider())
    } catch (error) {
      const text = authMessage(error)
      if (text) setNotice({ tone: "error", text })
      setBusy(false)
      return
    }
    try {
      const token = await user.getIdToken(true)
      const res = await fetch("/api/account/delete", {
        method: "POST",
        headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
        body: JSON.stringify({ confirm: "DELETE" }),
      })
      const payload = (res.headers.get("content-type") ?? "").includes("application/json") ? await res.json() : {}
      if (!res.ok) throw new Error(typeof payload.code === "string" ? payload.code : "server")
    } catch (error) {
      setNotice({ tone: "error", text: apiMessage(error instanceof Error ? error.message : "server") })
      setBusy(false)
      return
    }
    // The account is gone; clear this device too and leave the dashboard.
    await signOutAndClear()
    window.location.replace(`/${locale}`)
  }

  return (
    <section className="rounded-lg border" style={{ borderColor: "color-mix(in srgb, var(--expense) 40%, var(--border))", backgroundColor: "var(--bg-card)" }} aria-labelledby="danger-zone">
      <header className="border-b px-5 py-3.5" style={{ borderColor: "var(--border)" }}>
        <h2 id="danger-zone" className="text-sm font-semibold" style={{ color: "var(--expense)" }}>{t("title")}</h2>
      </header>
      <form onSubmit={remove} className="space-y-4 p-5">
        <div className="space-y-2 text-sm leading-6" style={{ color: "var(--text-secondary)" }}>
          <p>{t("intro")}</p>
          <ul className="list-disc space-y-1 pl-5">
            <li>{t("personal")}</li>
            <li>{t("profile")}</li>
            {isFamily && <li>{t("ownership")}</li>}
            {isFamily && <li>{t("shared")}</li>}
          </ul>
          <p className="font-medium" style={{ color: "var(--text-primary)" }}>{t("irreversible")}</p>
        </div>
        <div className="grid max-w-md gap-3">
          <div>
            <label htmlFor="delete-word" className="mb-1 block text-xs font-medium" style={{ color: "var(--text-secondary)" }}>{t("typeWord", { word: confirmWord })}</label>
            <input id="delete-word" value={word} onChange={(e) => setWord(e.target.value)} autoComplete="off" spellCheck={false} className="field w-full" />
          </div>
          {hasPassword ? (
            <Field id="delete-password" label={tAccount("currentPassword")} value={password} onChange={setPassword} autoComplete="current-password" />
          ) : hasGoogle ? (
            <p className="text-xs" style={{ color: "var(--text-muted)" }}>{t("googleReauth")}</p>
          ) : null}
          <button
            type="submit"
            disabled={!ready || busy}
            className="flex h-9 items-center justify-center justify-self-start rounded-md px-4 text-sm font-semibold disabled:cursor-not-allowed disabled:opacity-60"
            // Card colour as text keeps contrast in both themes (the red lightens in dark mode).
            style={{ backgroundColor: "var(--expense)", color: "var(--bg-card)" }}
          >
            {busy ? t("deleting") : t("button")}
          </button>
        </div>
        <NoticeLine notice={notice} />
      </form>
    </section>
  )
}

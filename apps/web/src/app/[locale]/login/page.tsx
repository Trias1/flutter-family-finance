"use client"

import { Suspense, useEffect, useState, type FormEvent, type ReactNode } from "react"
import { Eye, EyeOff } from "lucide-react"
import {
  createUserWithEmailAndPassword,
  GoogleAuthProvider,
  sendEmailVerification,
  sendPasswordResetEmail,
  signInWithEmailAndPassword,
  signInWithPopup,
  type User,
} from "firebase/auth"
import { doc, getDoc, serverTimestamp, setDoc } from "firebase/firestore"
import { useSearchParams } from "next/navigation"
import { useTranslations } from "next-intl"

import BrandMark from "@/components/public/BrandMark"
import PublicTheme from "@/components/public/PublicTheme"
import LocaleToggle from "@/components/LocaleToggle"
import { auth, db } from "@/lib/firebase"
import { Link, useRouter } from "@/lib/i18n"
import { clearFailures, getLockRemaining, recordFailure } from "@/lib/login-throttle"

type Mode = "login" | "register" | "reset"

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

function normalizeEmail(value: string) {
  return value.trim().toLowerCase()
}

function isStrongPassword(value: string) {
  return value.length >= 8 && /[A-Za-z]/.test(value) && /\d/.test(value)
}

function errorCode(error: unknown) {
  return typeof error === "object" && error !== null && "code" in error ? String((error as { code?: unknown }).code) : ""
}

function LoginForm() {
  const router = useRouter()
  const t = useTranslations("auth")
  const searchParams = useSearchParams()
  const [mode, setMode] = useState<Mode>(() => (searchParams.get("register") === "1" ? "register" : "login"))
  const [email, setEmail] = useState("")
  const [password, setPassword] = useState("")
  const [showPassword, setShowPassword] = useState(false)
  const [error, setError] = useState("")
  const [status, setStatus] = useState("")
  const [submitting, setSubmitting] = useState(false)
  const [lockSeconds, setLockSeconds] = useState(0)

  // Reads the stored lock after mount and ticks the countdown so the button
  // re-enables on its own.
  useEffect(() => {
    const tick = () => setLockSeconds(getLockRemaining())
    const first = window.setTimeout(tick, 0)
    const id = window.setInterval(tick, 1000)
    return () => {
      window.clearTimeout(first)
      window.clearInterval(id)
    }
  }, [])

  const safeEmail = normalizeEmail(email)
  const emailReady = emailPattern.test(safeEmail)
  const locked = lockSeconds > 0

  const switchMode = (next: Mode) => {
    setMode(next)
    setError("")
    setStatus("")
    setPassword("")
  }

  const failWith = (message: string) => {
    setLockSeconds(recordFailure())
    setError(message)
  }

  const messageFor = (error: unknown) => {
    const code = errorCode(error)
    if (code.includes("too-many-requests")) return t("errors.tooMany")
    if (code.includes("network-request-failed")) return t("errors.network")
    if (code.includes("popup-closed-by-user") || code.includes("cancelled-popup-request")) return ""
    if (mode === "register") return t("errors.registerFailed")
    return t("errors.invalidCredentials")
  }

  // Creates the profile on first sign-in. Role is never taken from the client:
  // new users are always plain members, admins are promoted server-side.
  const ensureUserDoc = async (user: User) => {
    const ref = doc(db, "users", user.uid)
    let snap = await getDoc(ref)
    const fallbackName = user.displayName || (user.email ?? "").split("@")[0] || "User"
    if (!snap.exists()) {
      await setDoc(ref, { name: fallbackName, email: user.email ?? "", role: "member", createdAt: serverTimestamp() })
      await setDoc(doc(db, "user_public", user.uid), { name: fallbackName, createdAt: serverTimestamp() }, { merge: true })
      snap = await getDoc(ref)
    }
    return snap
  }

  const finishSignIn = async (user: User) => {
    setStatus(t("redirecting"))
    try {
      const snap = await ensureUserDoc(user)
      router.push(snap.data()?.systemRole === "superadmin" ? "/admin" : "/dashboard")
    } catch {
      // Signed in, but profile sync failed; the dashboard retries it.
      router.push("/dashboard")
    }
  }

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault()
    if (submitting) return
    setError("")
    setStatus("")

    if (!emailReady) {
      setError(t("errors.invalidEmail"))
      return
    }
    if (mode !== "reset" && getLockRemaining() > 0) {
      setLockSeconds(getLockRemaining())
      return
    }

    if (mode === "reset") {
      setSubmitting(true)
      try {
        await sendPasswordResetEmail(auth, safeEmail)
      } catch {
        // Same answer whether or not the email exists.
      }
      setStatus(t("resetSent"))
      setSubmitting(false)
      return
    }

    if (mode === "register" && !isStrongPassword(password)) {
      setError(t("errors.weakPassword"))
      return
    }
    if (mode === "login" && password.length === 0) {
      setError(t("errors.invalidCredentials"))
      return
    }

    setSubmitting(true)
    try {
      if (mode === "register") {
        const cred = await createUserWithEmailAndPassword(auth, safeEmail, password)
        clearFailures()
        sendEmailVerification(cred.user).catch(() => {})
        await finishSignIn(cred.user)
      } else {
        const cred = await signInWithEmailAndPassword(auth, safeEmail, password)
        clearFailures()
        await finishSignIn(cred.user)
      }
    } catch (err) {
      failWith(messageFor(err))
    } finally {
      setSubmitting(false)
    }
  }

  const handleGoogle = async () => {
    if (submitting || locked) return
    setError("")
    setStatus("")
    setSubmitting(true)
    try {
      const provider = new GoogleAuthProvider()
      provider.setCustomParameters({ prompt: "select_account" })
      const cred = await signInWithPopup(auth, provider)
      clearFailures()
      await finishSignIn(cred.user)
    } catch (err) {
      const message = messageFor(err)
      if (message) setError(t("errors.googleFailed"))
    } finally {
      setSubmitting(false)
    }
  }

  const title = mode === "register" ? t("createYourAccount") : mode === "reset" ? t("resetTitle") : t("welcomeBack")
  const subtitle = mode === "register" ? t("secureWorkspace") : mode === "reset" ? t("resetDesc") : t("signInToAccount")
  const submitLabel = mode === "register" ? t("register") : mode === "reset" ? t("sendResetLink") : t("signIn")

  return (
    <main className="auth-page min-h-screen px-4 py-6 sm:py-10">
      <header className="mx-auto flex w-full max-w-md items-center justify-between">
        <Link href="/" className="flex items-center gap-2 text-sm font-semibold" style={{ color: "var(--text-primary)" }}>
          <BrandMark dark />
          Family Finance
        </Link>
        <LocaleToggle />
      </header>
      <PublicTheme />

      <section className="auth-card mx-auto mt-8 w-full max-w-md p-6 sm:p-8">
        <h1 className="text-2xl font-bold tracking-tight" style={{ color: "var(--text-primary)" }}>{title}</h1>
        <p className="mt-1 text-sm" style={{ color: "var(--text-secondary)" }}>{subtitle}</p>

        {mode !== "reset" && (
          <>
            <button type="button" onClick={handleGoogle} disabled={submitting || locked} className="auth-btn-secondary mt-6">
              <GoogleLogo />
              {t("continueWithGoogle")}
            </button>
            <div className="my-5 flex items-center gap-3 text-xs" style={{ color: "var(--text-muted)" }}>
              <span className="h-px flex-1" style={{ backgroundColor: "var(--border)" }} />
              {t("or")}
              <span className="h-px flex-1" style={{ backgroundColor: "var(--border)" }} />
            </div>
          </>
        )}

        <form onSubmit={handleSubmit} noValidate className={mode === "reset" ? "mt-6 space-y-4" : "space-y-4"}>
          <Field id="email" label={t("email")}>
            <input
              id="email"
              type="email"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              autoComplete="email"
              inputMode="email"
              maxLength={254}
              placeholder={t("enterEmail")}
              className="auth-input"
              required
            />
          </Field>

          {mode !== "reset" && (
            <Field
              id="password"
              label={t("password")}
              aside={mode === "login" ? (
                <button type="button" onClick={() => switchMode("reset")} className="text-xs font-medium" style={{ color: "var(--primary)" }}>
                  {t("forgotPassword")}
                </button>
              ) : null}
            >
              <div className="relative">
                <input
                  id="password"
                  type={showPassword ? "text" : "password"}
                  value={password}
                  onChange={(event) => setPassword(event.target.value)}
                  autoComplete={mode === "register" ? "new-password" : "current-password"}
                  maxLength={128}
                  placeholder={t("enterPassword")}
                  className="auth-input pr-10"
                  required
                />
                <button
                  type="button"
                  onClick={() => setShowPassword((value) => !value)}
                  aria-label={showPassword ? t("hidePassword") : t("showPassword")}
                  className="absolute inset-y-0 right-0 flex w-10 items-center justify-center"
                  style={{ color: "var(--text-muted)" }}
                >
                  {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                </button>
              </div>
              {mode === "register" && <p className="mt-1.5 text-xs" style={{ color: "var(--text-muted)" }}>{t("passwordHint")}</p>}
            </Field>
          )}

          <button type="submit" disabled={submitting || (locked && mode !== "reset")} className="auth-btn-primary">
            {locked && mode !== "reset" ? t("lockedFor", { seconds: lockSeconds }) : submitting ? t("loading") : submitLabel}
          </button>
        </form>

        <div aria-live="polite">
          {status && <p className="auth-notice auth-notice-ok mt-4">{status}</p>}
          {error && <p className="auth-notice auth-notice-error mt-4">{error}</p>}
        </div>

        <p className="mt-6 text-center text-sm" style={{ color: "var(--text-secondary)" }}>
          {mode === "reset" ? (
            <button type="button" onClick={() => switchMode("login")} className="font-semibold" style={{ color: "var(--primary)" }}>
              {t("backToLogin")}
            </button>
          ) : (
            <>
              {mode === "register" ? t("haveAccount") : t("noAccount")}{" "}
              <button type="button" onClick={() => switchMode(mode === "register" ? "login" : "register")} className="font-semibold" style={{ color: "var(--primary)" }}>
                {mode === "register" ? t("loginLink") : t("registerLink")}
              </button>
            </>
          )}
        </p>
      </section>
    </main>
  )
}

function Field({ id, label, aside, children }: { id: string; label: string; aside?: ReactNode; children: ReactNode }) {
  return (
    <div>
      <div className="mb-1.5 flex items-center justify-between">
        <label htmlFor={id} className="text-sm font-medium" style={{ color: "var(--text-primary)" }}>{label}</label>
        {aside}
      </div>
      {children}
    </div>
  )
}

function GoogleLogo() {
  return (
    <svg viewBox="0 0 24 24" className="h-4 w-4" aria-hidden="true">
      <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.27-4.74 3.27-8.1Z" fill="#4285F4" />
      <path d="M12 23c2.97 0 5.46-.98 7.29-2.65l-3.57-2.77c-.99.66-2.24 1.06-3.72 1.06-2.86 0-5.28-1.93-6.15-4.52H2.18v2.84A11 11 0 0 0 12 23Z" fill="#34A853" />
      <path d="M5.85 14.12A6.6 6.6 0 0 1 5.5 12c0-.73.13-1.43.35-2.12V7.04H2.18A11 11 0 0 0 1 12c0 1.77.42 3.45 1.18 4.96l2.87-2.84Z" fill="#FBBC05" />
      <path d="M12 5.36c1.61 0 3.05.55 4.19 1.63l3.14-3.14C17.45 2.08 14.97 1 12 1A11 11 0 0 0 2.18 7.04l3.67 2.84C6.72 7.29 9.14 5.36 12 5.36Z" fill="#EA4335" />
    </svg>
  )
}

export default function LoginPage() {
  return (
    <Suspense fallback={<div className="auth-page min-h-screen" />}>
      <LoginForm />
    </Suspense>
  )
}

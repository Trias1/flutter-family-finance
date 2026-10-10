"use client"

import { Suspense, useEffect, useState } from "react"
import { ArrowRight, LockKeyhole, Mail, ShieldCheck } from "lucide-react"
import {
  createUserWithEmailAndPassword,
  GoogleAuthProvider,
  signInWithEmailAndPassword,
  signInWithPopup,
} from "firebase/auth"
import { doc, getDoc, serverTimestamp, setDoc } from "firebase/firestore"

import AppPhonePreview from "@/components/public/AppPhonePreview"
import BrandMark from "@/components/public/BrandMark"
import ThemeToggle from "@/components/ThemeToggle"
import { auth, db } from "@/lib/firebase"
import { Link, useRouter } from "@/lib/i18n"
import { useTranslations } from "next-intl"

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
const genericAuthError = "Email atau password tidak valid. Coba cek lagi atau gunakan Google Sign-In."
const weakPasswordError = "Password minimal 8 karakter dan sebaiknya gunakan kombinasi huruf dan angka."

function normalizeEmail(value: string) {
  return value.trim().toLowerCase()
}

function LoginForm() {
  const router = useRouter()
  const t = useTranslations()
  const [email, setEmail] = useState("")
  const [password, setPassword] = useState("")
  const [isRegister, setIsRegister] = useState(false)
  const [error, setError] = useState("")
  const [status, setStatus] = useState("")
  const [submitting, setSubmitting] = useState(false)
  const [failedAttempts, setFailedAttempts] = useState(0)
  const [cooldownUntil, setCooldownUntil] = useState(0)

  useEffect(() => {
    if (typeof window === "undefined") return
    const params = new URLSearchParams(window.location.search)
    setIsRegister(params.get("register") === "1")
  }, [])

  const isCoolingDown = Date.now() < cooldownUntil
  const emailReady = emailPattern.test(normalizeEmail(email))
  const passwordReady = isRegister ? password.length >= 8 : password.length > 0
  const canSubmit = emailReady && passwordReady && !submitting && !isCoolingDown

  const getAuthErrorMessage = (error: unknown) => {
    const code = typeof error === "object" && error !== null && "code" in error ? String((error as { code?: unknown }).code) : ""
    if (code.includes("operation-not-allowed")) return "Login email/password belum aktif di Firebase Authentication. Aktifkan Email/Password provider dulu."
    if (code.includes("too-many-requests")) return "Terlalu banyak percobaan dari perangkat ini. Tunggu beberapa saat lalu coba lagi."
    if (code.includes("network-request-failed")) return "Koneksi bermasalah. Cek internet lalu coba lagi."
    if (code.includes("weak-password")) return weakPasswordError
    if (code.includes("email-already-in-use")) return "Email ini sudah terdaftar. Coba masuk/login saja."
    return genericAuthError
  }

  const registerFailure = (message = genericAuthError) => {
    const nextFailures = failedAttempts + 1
    setFailedAttempts(nextFailures)
    if (nextFailures >= 5) setCooldownUntil(Date.now() + 30_000)
    setError(nextFailures >= 5 ? "Terlalu banyak percobaan. Tunggu 30 detik lalu coba lagi." : message)
  }

  const ensureUserDoc = async (uid: string, userEmail: string, displayName?: string | null) => {
    const ref = doc(db, "users", uid)
    const snap = await getDoc(ref)
    const fallbackName = displayName || userEmail.split("@")[0] || "User"
    if (!snap.exists()) {
      await setDoc(ref, {
        name: fallbackName,
        email: userEmail,
        role: "member",
        createdAt: serverTimestamp(),
      })
    }
    await setDoc(doc(db, "user_public", uid), {
      name: snap.data()?.name ?? fallbackName,
      createdAt: snap.data()?.createdAt ?? serverTimestamp(),
    }, { merge: true })
    return getDoc(ref)
  }

  const handleEmailAuth = async () => {
    setError("")
    setStatus("")
    const safeEmail = normalizeEmail(email)
    if (!emailPattern.test(safeEmail)) {
      setError("Masukkan email yang valid. Login username belum didukung untuk web; gunakan email akun Firebase.")
      return
    }
    if (isRegister && password.length < 8) {
      setError(weakPasswordError)
      return
    }
    if (Date.now() < cooldownUntil) {
      setError("Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.")
      return
    }
    setSubmitting(true)
    try {
      const cred = isRegister
        ? await createUserWithEmailAndPassword(auth, safeEmail, password)
        : await signInWithEmailAndPassword(auth, safeEmail, password)
      setFailedAttempts(0)
      setCooldownUntil(0)
      setStatus("Login sukses. Mengalihkan ke dashboard...")
      const userSnap = await ensureUserDoc(cred.user.uid, safeEmail, cred.user.displayName)
      router.push(userSnap.data()?.systemRole === "superadmin" ? "/admin" : "/dashboard")
    } catch (error: unknown) {
      registerFailure(getAuthErrorMessage(error))
    } finally {
      setSubmitting(false)
    }
  }

  const handleGoogleAuth = async () => {
    setError("")
    setStatus("")
    if (Date.now() < cooldownUntil) {
      setError("Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.")
      return
    }
    setSubmitting(true)
    try {
      const provider = new GoogleAuthProvider()
      provider.setCustomParameters({ prompt: "select_account" })
      const cred = await signInWithPopup(auth, provider)
      setFailedAttempts(0)
      setCooldownUntil(0)
      setStatus("Login sukses. Mengalihkan ke dashboard...")
      const userSnap = await ensureUserDoc(cred.user.uid, cred.user.email ?? "", cred.user.displayName)
      router.push(userSnap.data()?.systemRole === "superadmin" ? "/admin" : "/dashboard")
    } catch {
      registerFailure("Google Sign-In gagal. Coba lagi atau gunakan email.")
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <main className="banking-page-bg relative min-h-screen overflow-hidden px-4 py-8">
      <div className="pointer-events-none absolute left-8 top-8 h-72 w-72 rounded-full bg-blue-500/20 blur-3xl" />
      <div className="pointer-events-none absolute bottom-0 right-8 h-80 w-80 rounded-full bg-cyan-400/20 blur-3xl" />

      <div className="relative z-10 mx-auto mb-6 flex w-full max-w-6xl items-center justify-between">
        <Link href="/" className="flex items-center gap-2 rounded-full px-4 py-2 text-fluid-sm font-black glass-card" style={{ color: "var(--text-primary)" }}>
          <BrandMark dark />
          Family Finance
        </Link>
        <ThemeToggle />
      </div>

      <div className="relative z-10 mx-auto grid min-h-[680px] w-full max-w-6xl overflow-hidden rounded-[2rem] glass-card lg:grid-cols-[0.95fr_1.05fr]">
        <section className="relative hidden overflow-hidden p-8 lg:block">
          <div className="absolute inset-8 rounded-[2rem] glass-panel-dark" />
          <div className="relative z-10 flex h-full flex-col justify-between p-8 text-white">
            <div>
              <div className="mb-5 inline-flex items-center gap-2 rounded-full bg-white/10 px-4 py-2 text-xs font-bold text-white/80 backdrop-blur">
                <ShieldCheck size={15} /> Secure access
              </div>
              <h2 className="max-w-sm responsive-section-title font-black">Masuk ke dashboard finance yang lebih trusted.</h2>
              <p className="mt-4 max-w-sm text-sm leading-7 text-white/68">Pantau cashflow, budget, goals, dan report dari web dengan visual digital banking yang konsisten.</p>
            </div>
            <div className="relative h-[360px]">
              <AppPhonePreview variant="dashboard" className="absolute left-8 top-0 scale-[0.88] rotate-[-6deg]" />
              <AppPhonePreview variant="reports" className="absolute bottom-[-70px] right-0 scale-[0.72] rotate-[10deg] opacity-90" />
            </div>
          </div>
        </section>

        <section className="flex flex-col justify-center px-6 py-10 sm:px-10 lg:px-14">
          <div className="mx-auto w-full max-w-md">
            <p className="text-fluid-sm font-bold uppercase tracking-[0.24em]" style={{ color: "var(--primary)" }}>
              {isRegister ? t("auth.createAccount") : t("auth.loginAccount")}
            </p>
            <h1 className="mt-3 responsive-section-title font-black" style={{ color: "var(--text-primary)" }}>
              {isRegister ? t("auth.createYourAccount") : t("auth.welcomeBack")}
            </h1>
            <p className="mt-3 text-fluid-sm leading-6" style={{ color: "var(--text-secondary)" }}>
              {isRegister ? t("auth.secureWorkspace") : t("auth.signInToAccount")}
            </p>

            <div className="mt-8 space-y-4">
              <SocialButton label={t("auth.continueWithGoogle")} onClick={handleGoogleAuth} disabled={submitting}>
                <GoogleLogo />
              </SocialButton>

              <div className="flex items-center gap-3 py-2 text-xs font-bold uppercase tracking-[0.18em]" style={{ color: "var(--text-muted)" }}>
                <span className="h-px flex-1" style={{ backgroundColor: "var(--border)" }} />
                {t("auth.or")}
                <span className="h-px flex-1" style={{ backgroundColor: "var(--border)" }} />
              </div>

              <Field icon={<Mail size={18} />} label={t("auth.email")}>
                <input
                  type="email"
                  value={email}
                  onChange={(event) => setEmail(event.target.value)}
                  autoComplete="email"
                  inputMode="email"
                  placeholder={t("auth.enterEmail")}
                  className="w-full bg-transparent text-sm outline-none placeholder:text-slate-400"
                  style={{ color: "var(--text-primary)" }}
                />
              </Field>

              <Field icon={<LockKeyhole size={18} />} label={t("auth.password")}>
                <input
                  type="password"
                  value={password}
                  onChange={(event) => setPassword(event.target.value)}
                  autoComplete={isRegister ? "new-password" : "current-password"}
                  placeholder={t("auth.enterPassword")}
                  className="w-full bg-transparent text-sm outline-none placeholder:text-slate-400"
                  style={{ color: "var(--text-primary)" }}
                />
              </Field>

              <button
                type="button"
                onClick={handleEmailAuth}
                disabled={submitting || isCoolingDown}
                className="flex w-full items-center justify-center gap-3 rounded-2xl px-5 py-4 text-fluid-sm font-black text-white shadow-lg transition-transform hover:-translate-y-0.5 disabled:cursor-not-allowed disabled:opacity-60"
                style={{ backgroundColor: "var(--primary)" }}
              >
                {isCoolingDown ? "Tunggu sebentar" : submitting ? t("auth.loading") : isRegister ? t("auth.register") : t("auth.signIn")}
                <ArrowRight size={17} />
              </button>
            </div>

            {!emailReady && email.length > 0 && <p className="mt-3 rounded-2xl bg-amber-50 px-4 py-3 text-sm text-amber-700">Masukkan format email yang valid. Untuk saat ini login web belum pakai username.</p>}
            {isRegister && password.length > 0 && password.length < 8 && <p className="mt-3 rounded-2xl bg-amber-50 px-4 py-3 text-sm text-amber-700">{weakPasswordError}</p>}
            {status && <p className="mt-4 rounded-2xl bg-emerald-50 px-4 py-3 text-sm text-emerald-700">{status}</p>}
            {error && <p className="mt-4 rounded-2xl bg-red-50 px-4 py-3 text-sm text-red-500">{error}</p>}

            <p className="mt-8 text-center text-sm" style={{ color: "var(--text-secondary)" }}>
              {isRegister ? t("auth.haveAccount") : t("auth.noAccount")} {" "}
              <button type="button" onClick={() => setIsRegister((value) => !value)} className="font-black" style={{ color: "var(--primary)" }}>
                {isRegister ? t("auth.loginLink") : t("auth.registerLink")}
              </button>
            </p>
          </div>
        </section>
      </div>
    </main>
  )
}

function Field({ icon, label, children }: { icon: React.ReactNode; label: string; children: React.ReactNode }) {
  return (
    <div className="rounded-2xl px-4 py-3 glass-card">
      <div className="flex items-center gap-3">
        <span style={{ color: "var(--primary)" }}>{icon}</span>
        <div className="min-w-0 flex-1 text-left">
          <p className="text-[11px] font-bold uppercase tracking-[0.12em]" style={{ color: "var(--text-muted)" }}>{label}</p>
          <div className="mt-1">{children}</div>
        </div>
      </div>
    </div>
  )
}

function SocialButton({ children, label, onClick, disabled }: { children: React.ReactNode; label: string; onClick: () => void; disabled?: boolean }) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      className="flex w-full items-center justify-between rounded-2xl px-4 py-4 text-fluid-sm font-bold transition-transform hover:-translate-y-0.5 disabled:cursor-not-allowed disabled:opacity-60 glass-card"
      style={{ color: "var(--text-primary)" }}
    >
      <span className="flex items-center gap-3">
        <span className="flex h-5 w-5 items-center justify-center">{children}</span>
        {label}
      </span>
      <ArrowRight size={17} style={{ color: "var(--text-muted)" }} />
    </button>
  )
}

function GoogleLogo() {
  return (
    <svg viewBox="0 0 24 24" className="h-5 w-5">
      <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.27-4.74 3.27-8.1Z" fill="#4285F4" />
      <path d="M12 23c2.97 0 5.46-.98 7.29-2.65l-3.57-2.77c-.99.66-2.24 1.06-3.72 1.06-2.86 0-5.28-1.93-6.15-4.52H2.18v2.84A11 11 0 0 0 12 23Z" fill="#34A853" />
      <path d="M5.85 14.12A6.6 6.6 0 0 1 5.5 12c0-.73.13-1.43.35-2.12V7.04H2.18A11 11 0 0 0 1 12c0 1.77.42 3.45 1.18 4.96l2.87-2.84Z" fill="#FBBC05" />
      <path d="M12 5.36c1.61 0 3.05.55 4.19 1.63l3.14-3.14C17.45 2.08 14.97 1 12 1A11 11 0 0 0 2.18 7.04l3.67 2.84C6.72 7.29 9.14 5.36 12 5.36Z" fill="#EA4335" />
    </svg>
  )
}

export default function LoginPage() {
  return (
    <Suspense fallback={<div className="banking-page-bg min-h-screen" />}>
      <LoginForm />
    </Suspense>
  )
}




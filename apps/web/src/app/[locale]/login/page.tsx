"use client"

import { Suspense, useEffect, useState } from "react"
import { ArrowRight, LockKeyhole, Mail } from "lucide-react"
import {
  createUserWithEmailAndPassword,
  GoogleAuthProvider,
  signInWithEmailAndPassword,
  signInWithPopup,
} from "firebase/auth"
import { doc, getDoc, serverTimestamp, setDoc } from "firebase/firestore"

import AppPhonePreview from "@/components/public/AppPhonePreview"
import AppThemedBackground from "@/components/public/AppThemedBackground"
import BrandMark from "@/components/public/BrandMark"
import { auth, db } from "@/lib/firebase"
import { Link, useRouter } from "@/lib/i18n"
import { useTranslations } from "next-intl"

function LoginForm() {
  const router = useRouter()
  const t = useTranslations()
  const [email, setEmail] = useState("")
  const [password, setPassword] = useState("")
  const [isRegister, setIsRegister] = useState(false)
  const [error, setError] = useState("")
  const [submitting, setSubmitting] = useState(false)

  useEffect(() => {
    if (typeof window === "undefined") return
    const params = new URLSearchParams(window.location.search)
    setIsRegister(params.get("register") === "1")
  }, [])

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
    setSubmitting(true)
    try {
      const cred = isRegister
        ? await createUserWithEmailAndPassword(auth, email, password)
        : await signInWithEmailAndPassword(auth, email, password)
      const userSnap = await ensureUserDoc(cred.user.uid, email, cred.user.displayName)
      router.push(userSnap.data()?.systemRole === "superadmin" ? "/admin" : "/dashboard")
    } catch (e: any) {
      setError(e.message)
    } finally {
      setSubmitting(false)
    }
  }

  const handleGoogleAuth = async () => {
    setError("")
    setSubmitting(true)
    try {
      const provider = new GoogleAuthProvider()
      const cred = await signInWithPopup(auth, provider)
      const userSnap = await ensureUserDoc(cred.user.uid, cred.user.email ?? "", cred.user.displayName)
      router.push(userSnap.data()?.systemRole === "superadmin" ? "/admin" : "/dashboard")
    } catch (e: any) {
      setError(e.message)
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div className="relative min-h-screen overflow-hidden bg-black px-4 py-8">
      <AppThemedBackground compact />
      <div className="fixed inset-0 bg-black/10 backdrop-blur-sm" />

      <div className="relative z-10 mx-auto flex min-h-[650px] w-full max-w-[1040px] flex-col overflow-hidden rounded-[2.5rem] border border-gray-200 bg-white shadow-[0_40px_120px_rgba(0,0,0,0.35)] lg:flex-row">
        <div className="relative min-h-[260px] lg:min-h-full lg:w-[45%]">
          <div className="absolute inset-4 overflow-hidden rounded-[2rem] bg-[#0c0c0e]">
            <div className="absolute inset-0 bg-[radial-gradient(circle_at_top,_rgba(102,187,106,0.24),_transparent_34%),linear-gradient(180deg,_#0B1020_0%,_#071019_48%,_#05070D_100%)]" />
            <AppPhonePreview variant="dashboard" className="absolute left-1/2 top-8 -translate-x-1/2 scale-[0.95] rotate-[-5deg]" />
            <AppPhonePreview variant="reports" className="absolute -bottom-10 right-[-18px] scale-[0.72] rotate-[12deg] opacity-90" />
          </div>
        </div>

        <div className="relative flex flex-1 flex-col justify-between px-6 py-8 sm:px-10 lg:w-[55%] lg:px-14 lg:py-12">
          <div className="absolute left-0 top-0 h-64 w-64 rounded-full blur-[80px]" style={{ background: "linear-gradient(135deg, rgba(255,81,47,0.2), rgba(240,152,25,0.2))" }} />

          <div className="relative z-10">
            <Link href="/" className="mx-auto mb-8 flex w-fit items-center gap-2 rounded-full border border-gray-200 bg-white/70 px-4 py-2 text-sm font-semibold text-[#111111] backdrop-blur-sm">
              <BrandMark dark />
              Family Finance
            </Link>

            <div className="text-center">
              <h1 className="text-[32px] font-semibold tracking-[-0.04em] text-[#111111] sm:text-[40px]">
                {isRegister ? t("auth.createYourAccount") : t("auth.welcomeBack")}
              </h1>
              <p className="mt-2 text-sm text-gray-500">
                {isRegister ? t("auth.secureWorkspace") : t("auth.signInToAccount")}
              </p>
            </div>

            <div className="mt-8 grid gap-3">
              <SocialButton label={t("auth.continueWithGoogle")} onClick={handleGoogleAuth}>
                <GoogleLogo />
              </SocialButton>
            </div>

            <div className="my-7 flex items-center gap-3">
              <div className="h-px flex-1 bg-gradient-to-r from-transparent via-gray-200 to-gray-200" />
              <span className="text-[10px] font-semibold uppercase tracking-[0.35em] text-gray-400">{t("auth.or")}</span>
              <div className="h-px flex-1 bg-gradient-to-l from-transparent via-gray-200 to-gray-200" />
            </div>

            <div className="space-y-4">
              <div className="group rounded-[1.25rem] border border-gray-200 bg-gray-50 p-2 transition-all focus-within:border-gray-400 focus-within:bg-white">
                <div className="flex items-center gap-3">
                  <div className="flex min-w-0 flex-1 items-center gap-3 rounded-[1rem] px-3 py-2.5">
                    <Mail className="h-4.5 w-4.5 text-gray-400" />
                    <div className="min-w-0 flex-1 text-left">
                      <p className="text-[11px] font-medium text-gray-500">{t("auth.email")}</p>
                      <input
                        type="email"
                        value={email}
                        onChange={(event) => setEmail(event.target.value)}
                        placeholder={t("auth.enterEmail")}
                        className="w-full bg-transparent text-sm text-[#111111] outline-none placeholder:text-gray-400"
                      />
                    </div>
                  </div>

                  <button
                    type="button"
                    onClick={handleEmailAuth}
                    disabled={submitting}
                    className="group/submit relative flex h-[52px] w-[52px] shrink-0 items-center justify-center rounded-full"
                  >
                    <span className="absolute inset-0 rounded-full bg-[conic-gradient(#00c6ff,#0072ff,#ff007a,#ff8a00,#00c6ff)] p-[3px] transition-transform duration-500 group-hover/submit:animate-spin">
                      <span className="block h-full w-full rounded-full bg-white" />
                    </span>
                    <span className="absolute inset-[-8px] rounded-full bg-[conic-gradient(#00c6ff,#0072ff,#ff007a,#ff8a00,#00c6ff)] opacity-0 blur-md transition-opacity duration-300 group-hover/submit:animate-spin group-hover/submit:opacity-100" />
                    <span className="relative z-10 flex h-[46px] w-[46px] items-center justify-center rounded-full bg-[#111111] shadow-[inset_0_1px_1px_rgba(255,255,255,0.12),inset_0_-4px_8px_rgba(0,0,0,0.4)]">
                      <ArrowRight className="h-4.5 w-4.5 text-white transition-transform duration-200 group-hover/submit:translate-x-0.5" />
                    </span>
                  </button>
                </div>
              </div>

              <div className="rounded-[1.25rem] border border-gray-200 bg-gray-50 px-4 py-3 transition-all focus-within:border-gray-400 focus-within:bg-white">
                <div className="flex items-center gap-3">
                  <LockKeyhole className="h-4.5 w-4.5 text-gray-400" />
                  <div className="min-w-0 flex-1 text-left">
                      <p className="text-[11px] font-medium text-gray-500">{t("auth.password")}</p>
                      <input
                      type="password"
                      value={password}
                      onChange={(event) => setPassword(event.target.value)}
                        placeholder={t("auth.enterPassword")}
                      className="w-full bg-transparent text-sm text-[#111111] outline-none placeholder:text-gray-400"
                    />
                  </div>
                </div>
              </div>
            </div>

            {error && <p className="mt-4 rounded-2xl bg-red-50 px-4 py-3 text-sm text-red-500">{error}</p>}
          </div>

          <p className="relative z-10 mt-8 text-center text-sm text-gray-500">
            {isRegister ? t("auth.haveAccount") : t("auth.noAccount")}{" "}
            <button
              type="button"
              onClick={() => setIsRegister((value) => !value)}
              className="bg-gradient-to-r from-[#FF512F] to-[#F09819] bg-clip-text font-semibold text-transparent"
            >
              {isRegister ? t("auth.loginLink") : t("auth.registerLink")}
            </button>
          </p>
        </div>
      </div>
    </div>
  )
}

function SocialButton({ children, label, onClick }: { children: React.ReactNode; label: string; onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="flex w-full items-center justify-between rounded-[1.25rem] border border-gray-200 bg-gray-50 px-4 py-4 text-sm font-medium text-[#111111] transition-all hover:border-gray-300 hover:bg-white"
    >
      <span className="flex items-center gap-3">
        <span className="flex h-5 w-5 items-center justify-center">{children}</span>
        {label}
      </span>
      <ArrowRight className="h-4.5 w-4.5 text-gray-500 transition-colors group-hover:text-[#111111]" />
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
    <Suspense fallback={<div className="min-h-screen bg-black" />}>
      <LoginForm />
    </Suspense>
  )
}

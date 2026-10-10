"use client"

import { useEffect, useState, useRef } from "react"
import { onAuthStateChanged, signOut, User } from "firebase/auth"
import { doc, getDoc } from "firebase/firestore"
import { auth, db } from "@/lib/firebase"
import { useRouter } from "@/lib/i18n"
import { useTranslations } from "next-intl"
import LocaleToggle from "@/components/LocaleToggle"
import Sidebar from "@/components/Sidebar"
import ThemeToggle from "@/components/ThemeToggle"
import { startWebPresence } from "@/lib/web-presence"

export default function DashboardShell({ children }: { children: React.ReactNode }) {
  const t = useTranslations()
  const router = useRouter()
  const [user, setUser] = useState<User | null>(null)
  const [role, setRole] = useState<string | null>(null)
  const [sidebarOpen, setSidebarOpen] = useState(false)
  const [dropdownOpen, setDropdownOpen] = useState(false)
  const [loading, setLoading] = useState(true)
  const dropdownRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    let stopPresence: (() => void) | undefined

    const unsub = onAuthStateChanged(auth, async (u) => {
      if (!u) {
        stopPresence?.()
        router.push("/login")
        return
      }
      setUser(u)
      const snap = await getDoc(doc(db, "users", u.uid))
      const systemRole = snap.data()?.systemRole ?? null
      const nextRole = snap.data()?.role ?? "user"
      setRole(nextRole)
      if (systemRole === "superadmin") {
        router.push("/admin")
        return
      }
      stopPresence?.()
      stopPresence = startWebPresence(u.uid, u.email)
      setLoading(false)
    })
    return () => {
      stopPresence?.()
      unsub()
    }
  }, [router])

  useEffect(() => {
    const handleClick = (e: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target as Node)) {
        setDropdownOpen(false)
      }
    }
    document.addEventListener("mousedown", handleClick)
    return () => document.removeEventListener("mousedown", handleClick)
  }, [])

  const handleSignOut = async () => {
    setDropdownOpen(false)
    await signOut(auth)
    router.push("/login")
  }

  if (loading) {
      return (
      <div className="flex min-h-screen items-center justify-center" style={{ backgroundColor: "var(--bg)" }}>
        <div className="h-10 w-10 animate-spin rounded-full border-4 border-t-transparent" style={{ borderColor: "var(--border)", borderTopColor: "var(--primary)" }} />
      </div>
    )
  }

  return (
    <div className="flex h-screen overflow-hidden" style={{ color: "var(--text-primary)" }}>
      <Sidebar user={user} role={role} isOpen={sidebarOpen} onClose={() => setSidebarOpen(false)} />

      <div className="flex-1 flex flex-col min-w-0">
        {/* Top Navbar */}
        <header className="sticky top-0 z-30 border-b backdrop-blur-md" style={{ backgroundColor: "color-mix(in srgb, var(--bg-card) 72%, transparent)", borderColor: "rgba(255,255,255,0.62)", backdropFilter: "blur(22px)" }}>
          <div className="flex h-16 items-center justify-between px-4 lg:px-6">
            <button
              onClick={() => setSidebarOpen(true)}
              className="flex h-9 w-9 items-center justify-center rounded-xl transition-colors lg:hidden"
              style={{ color: "var(--text-secondary)" }}
              onMouseEnter={(e) => { e.currentTarget.style.backgroundColor = "var(--surface-soft)" }}
              onMouseLeave={(e) => { e.currentTarget.style.backgroundColor = "transparent" }}
            >
              <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M4 6h16M4 12h16M4 18h16" />
              </svg>
            </button>

            <div className="hidden lg:block" />

            {/* User dropdown */}
            <div className="relative flex items-center gap-3" ref={dropdownRef}>
              <LocaleToggle />
              <ThemeToggle />
              <button
                onClick={() => setDropdownOpen(!dropdownOpen)}
                className="flex items-center gap-2 rounded-xl px-3 py-1.5 text-sm font-medium transition-all duration-200"
                style={{ color: "var(--text-secondary)" }}
                onMouseEnter={(e) => { e.currentTarget.style.backgroundColor = "var(--surface-soft)" }}
                onMouseLeave={(e) => { e.currentTarget.style.backgroundColor = "transparent" }}
              >
                <div className="flex h-7 w-7 items-center justify-center rounded-full text-xs font-bold text-white" style={{ backgroundColor: "var(--primary)" }}>
                  {user?.email?.charAt(0).toUpperCase() || "U"}
                </div>
                <span className="hidden sm:block max-w-[160px] truncate">{user?.email}</span>
                <svg className={`h-4 w-4 transition-transform ${dropdownOpen ? "rotate-180" : ""}`} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M19 9l-7 7-7-7" />
                </svg>
              </button>

              {dropdownOpen && (
                <div
                  className="absolute right-0 mt-2 w-48 rounded-xl border shadow-lg backdrop-blur-md animate-scale-in origin-top-right"
                  style={{ backgroundColor: "color-mix(in srgb, var(--bg-card) 96%, transparent)", borderColor: "var(--border)", boxShadow: "var(--shadow-soft)" }}
                >
                  <div className="px-4 py-3 border-b" style={{ borderColor: "var(--border)" }}>
                    <p className="text-sm font-medium truncate" style={{ color: "var(--text-primary)" }}>{user?.email}</p>
                    {role === "admin" && <span className="text-xs font-medium" style={{ color: "var(--primary)" }}>{t("nav.admin")}</span>}
                  </div>
                  {role === "admin" && (
                    <button
                      onClick={() => { setDropdownOpen(false); router.push("/admin") }}
                      className="flex w-full items-center gap-2 px-4 py-2.5 text-sm transition-colors"
                      style={{ color: "var(--text-secondary)" }}
                      onMouseEnter={(e) => { e.currentTarget.style.backgroundColor = "var(--surface-soft)" }}
                      onMouseLeave={(e) => { e.currentTarget.style.backgroundColor = "transparent" }}
                    >
                      ⚙️ {t("nav.admin")}
                    </button>
                  )}
                  <button
                    onClick={handleSignOut}
                    className="flex w-full items-center gap-2 px-4 py-2.5 text-sm transition-colors rounded-b-xl"
                    style={{ color: "var(--expense)" }}
                    onMouseEnter={(e) => { e.currentTarget.style.backgroundColor = "var(--surface-soft)" }}
                    onMouseLeave={(e) => { e.currentTarget.style.backgroundColor = "transparent" }}
                  >
                    🚪 {t("common.signOut")}
                  </button>
                </div>
              )}
            </div>
          </div>
        </header>

        <main className="flex-1 overflow-y-auto px-4 lg:px-6 py-6">
          {children}
        </main>
      </div>
    </div>
  )
}


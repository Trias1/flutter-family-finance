"use client"

import { useEffect, useRef, useState, type ReactNode } from "react"
import { onAuthStateChanged, type User } from "firebase/auth"
import { doc, getDoc } from "firebase/firestore"
import { BookOpen, ChevronDown, LogOut, Shield } from "lucide-react"
import { useLocale, useTranslations } from "next-intl"

import LocaleToggle from "@/components/LocaleToggle"
import Sidebar, { MobileNav } from "@/components/Sidebar"
import SyncStatus from "@/components/SyncStatus"
import ThemeToggle from "@/components/ThemeToggle"
import { Skeleton } from "@/components/ui"
import { FamilyDataProvider } from "@/lib/family-data"
import { auth, db, signOutAndClear } from "@/lib/firebase"
import { Link, useRouter } from "@/lib/i18n"
import { startWebPresence } from "@/lib/web-presence"

export default function DashboardShell({ children }: { children: ReactNode }) {
  const t = useTranslations("dash")
  const locale = useLocale()
  const router = useRouter()
  const [user, setUser] = useState<User | null>(null)
  const [isSuperadmin, setIsSuperadmin] = useState(false)
  const [menuOpen, setMenuOpen] = useState(false)
  const menuRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    let stopPresence: (() => void) | undefined
    const unsub = onAuthStateChanged(auth, async (u) => {
      stopPresence?.()
      if (!u) {
        setUser(null)
        router.replace("/login")
        return
      }
      setUser(u)
      stopPresence = startWebPresence(u.uid)
      try {
        const snap = await getDoc(doc(db, "users", u.uid))
        setIsSuperadmin(snap.data()?.systemRole === "superadmin")
      } catch {
        setIsSuperadmin(false)
      }
    })
    return () => {
      stopPresence?.()
      unsub()
    }
  }, [router])

  useEffect(() => {
    if (!menuOpen) return
    const close = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) setMenuOpen(false)
    }
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setMenuOpen(false)
    document.addEventListener("mousedown", close)
    document.addEventListener("keydown", onKey)
    return () => {
      document.removeEventListener("mousedown", close)
      document.removeEventListener("keydown", onKey)
    }
  }, [menuOpen])

  const handleSignOut = async () => {
    setMenuOpen(false)
    await signOutAndClear()
    // Full page load: the Firestore instance is terminated after clearing its cache.
    window.location.replace(`/${locale}/login`)
  }

  if (!user) {
    return (
      <div className="flex min-h-dvh" style={{ backgroundColor: "var(--bg)" }} aria-busy="true">
        <div className="hidden w-56 shrink-0 border-r lg:block" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }} />
        <div className="flex-1">
          <div className="h-14 border-b" style={{ borderColor: "var(--border)" }} />
          <div className="mx-auto max-w-[1200px] space-y-6 px-4 py-6 sm:px-6">
            <Skeleton className="h-7 w-40" />
            <Skeleton className="h-[106px] w-full" />
            <Skeleton className="h-64 w-full" />
          </div>
        </div>
      </div>
    )
  }

  const initial = (user.displayName || user.email || "U").charAt(0).toUpperCase()

  return (
    <FamilyDataProvider uid={user.uid}>
      <div className="flex min-h-dvh" style={{ backgroundColor: "var(--bg)", color: "var(--text-primary)" }}>
        <Sidebar />

        <div className="flex min-w-0 flex-1 flex-col">
          <header className="sticky top-0 z-30 border-b" style={{ backgroundColor: "var(--bg)", borderColor: "var(--border)" }}>
            <div className="mx-auto flex h-14 max-w-[1200px] items-center justify-between gap-3 px-4 sm:px-6">
              <SyncStatus />

              <div className="flex items-center gap-2" ref={menuRef}>
                <div className="hidden items-center gap-2 sm:flex">
                  <LocaleToggle />
                  <ThemeToggle />
                </div>
                <div className="relative">
                  <button
                    type="button"
                    onClick={() => setMenuOpen((v) => !v)}
                    aria-expanded={menuOpen}
                    aria-haspopup="menu"
                    className="flex h-8 items-center gap-2 rounded-md pl-1 pr-2 text-sm"
                    style={{ color: "var(--text-secondary)" }}
                  >
                    <span className="flex h-6 w-6 items-center justify-center rounded-full text-xs font-semibold text-white" style={{ backgroundColor: "var(--primary)" }}>{initial}</span>
                    <span className="hidden max-w-[180px] truncate md:block">{user.email}</span>
                    <ChevronDown size={14} />
                  </button>

                  {menuOpen && (
                    <div role="menu" className="absolute right-0 mt-1 w-60 overflow-hidden rounded-lg border text-sm" style={{ backgroundColor: "var(--bg-card)", borderColor: "var(--border)" }}>
                      <div className="border-b px-3 py-2.5" style={{ borderColor: "var(--border)" }}>
                        <p className="truncate font-medium" style={{ color: "var(--text-primary)" }}>{user.displayName || user.email}</p>
                        {user.displayName && <p className="truncate text-xs" style={{ color: "var(--text-muted)" }}>{user.email}</p>}
                      </div>
                      <div className="flex items-center gap-2 border-b px-3 py-2.5 sm:hidden" style={{ borderColor: "var(--border)" }}>
                        <LocaleToggle />
                        <ThemeToggle />
                      </div>
                      <Link href="/dashboard/guide" role="menuitem" onClick={() => setMenuOpen(false)} className="menu-item">
                        <BookOpen size={15} /> {t("nav.guide")}
                      </Link>
                      {isSuperadmin && (
                        <Link href="/admin" role="menuitem" onClick={() => setMenuOpen(false)} className="menu-item">
                          <Shield size={15} /> {t("nav.admin")}
                        </Link>
                      )}
                      <button type="button" role="menuitem" onClick={handleSignOut} className="menu-item w-full" style={{ color: "var(--expense)" }}>
                        <LogOut size={15} /> {t("nav.signOut")}
                      </button>
                    </div>
                  )}
                </div>
              </div>
            </div>
          </header>

          <main className="flex-1 pb-24 lg:pb-10">
            <div className="mx-auto max-w-[1200px] px-4 py-6 sm:px-6">{children}</div>
          </main>
        </div>

        <MobileNav />
      </div>
    </FamilyDataProvider>
  )
}

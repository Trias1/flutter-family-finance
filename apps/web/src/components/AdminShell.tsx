"use client"

import { useEffect, useRef, useState } from "react"
import Link from "next/link"
import { useTranslations } from "next-intl"
import { signOut, User } from "firebase/auth"
import { Menu, X } from "lucide-react"

import LocaleToggle from "@/components/LocaleToggle"
import ThemeToggle from "@/components/ThemeToggle"
import { APP_NAME, APP_VERSION_LABEL } from "@/lib/app-info"
import { auth } from "@/lib/firebase"
import { useRouter } from "@/lib/i18n"

export default function AdminShell({ user, children }: { user: User | null; children: React.ReactNode }) {
  const router = useRouter()
  const t = useTranslations()
  const [dropdownOpen, setDropdownOpen] = useState(false)
  const [sidebarOpen, setSidebarOpen] = useState(false)
  const dropdownRef = useRef<HTMLDivElement>(null)

  const items = [
    { href: "#overview", label: t("admin.overview") },
    { href: "#charts", label: t("admin.charts") },
    { href: "#users", label: t("admin.users") },
    { href: "#registry", label: t("admin.usersRegistry") },
    { href: "#devices", label: t("admin.devicePresence") },
    { href: "#versions", label: t("admin.versionControl") },
  ]

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

  return (
    <div className="min-h-screen" style={{ backgroundColor: "var(--bg)", color: "var(--text-primary)" }}>
      <div className="flex min-h-screen">
        {sidebarOpen && <div className="fixed inset-0 z-30 bg-black/30 lg:hidden" onClick={() => setSidebarOpen(false)} />}

        <aside className={`fixed inset-y-0 left-0 z-40 w-72 border-r transition-transform lg:static lg:translate-x-0 ${sidebarOpen ? "translate-x-0" : "-translate-x-full"}`} style={{ backgroundColor: "var(--bg-card)", borderColor: "var(--border)" }}>
          <div className="flex h-16 items-center justify-between border-b px-5" style={{ borderColor: "var(--border)" }}>
            <div>
              <p className="text-xs font-semibold uppercase tracking-[0.26em]" style={{ color: "var(--text-muted)" }}>{t("admin.workspace")}</p>
              <p className="text-lg font-semibold" style={{ color: "var(--primary)" }}>{APP_NAME}</p>
            </div>
            <button className="lg:hidden" onClick={() => setSidebarOpen(false)}><X size={18} /></button>
          </div>

          <div className="px-4 py-5">
            <div className="rounded-2xl border px-4 py-3" style={{ backgroundColor: "var(--surface-soft)", borderColor: "var(--border)" }}>
              <p className="text-[11px] uppercase tracking-[0.24em]" style={{ color: "var(--text-muted)" }}>{t("admin.currentWeb")}</p>
              <p className="mt-2 text-sm font-semibold" style={{ color: "var(--text-primary)" }}>v{APP_VERSION_LABEL}</p>
            </div>
            <nav className="mt-6 space-y-2">
              {items.map((item) => (
                <Link key={item.href} href={item.href} className="block rounded-xl px-4 py-3 text-sm font-medium" style={{ color: "var(--text-secondary)" }}>
                  {item.label}
                </Link>
              ))}
            </nav>
          </div>
        </aside>

        <div className="min-w-0 flex-1">
          <header className="sticky top-0 z-20 border-b backdrop-blur-md" style={{ backgroundColor: "color-mix(in srgb, var(--bg-card) 92%, transparent)", borderColor: "var(--border)" }}>
            <div className="mx-auto flex h-16 max-w-full items-center justify-between px-4 lg:px-6">
              <div className="flex items-center gap-3">
                <button className="rounded-xl p-2 lg:hidden" onClick={() => setSidebarOpen(true)}><Menu size={18} /></button>
                <div>
                  <p className="text-sm font-semibold" style={{ color: "var(--primary)" }}>{t("admin.adminMonitoring")}</p>
                  <p className="text-xs lg:hidden" style={{ color: "var(--text-muted)" }}>Family Finance</p>
                </div>
              </div>

              <div className="flex items-center gap-3">
                <LocaleToggle />
                <ThemeToggle />
                <div className="relative" ref={dropdownRef}>
                  <button
                    onClick={() => setDropdownOpen((value) => !value)}
                    className="flex items-center gap-2 rounded-xl px-3 py-2 text-sm font-medium"
                    style={{ color: "var(--text-secondary)" }}
                  >
                    <div className="flex h-8 w-8 items-center justify-center rounded-full text-xs font-bold text-white" style={{ backgroundColor: "var(--primary)" }}>
                      {user?.email?.charAt(0).toUpperCase() || "A"}
                    </div>
                    <span className="hidden sm:block">{user?.email}</span>
                  </button>

                  {dropdownOpen && (
                    <div className="absolute right-0 mt-2 w-56 rounded-2xl border p-2" style={{ backgroundColor: "var(--bg-card)", borderColor: "var(--border)", boxShadow: "var(--shadow-soft)" }}>
                      <button
                        onClick={() => {
                          setDropdownOpen(false)
                          router.push("/dashboard")
                        }}
                        className="flex w-full rounded-xl px-3 py-2 text-sm"
                        style={{ color: "var(--text-secondary)" }}
                      >
                        {t("admin.userDashboard")}
                      </button>
                      <button
                        onClick={handleSignOut}
                        className="flex w-full rounded-xl px-3 py-2 text-sm"
                        style={{ color: "var(--expense)" }}
                      >
                        {t("common.signOut")}
                      </button>
                    </div>
                  )}
                </div>
              </div>
            </div>
          </header>

          <main className="mx-auto max-w-full px-4 py-6 lg:px-6">{children}</main>
        </div>
      </div>
    </div>
  )
}

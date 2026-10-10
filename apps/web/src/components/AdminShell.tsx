"use client"

import { useEffect, useRef, useState, type ReactNode } from "react"
import { type User } from "firebase/auth"
import { ChevronDown, LayoutGrid, LogOut, PackageCheck, ScrollText, Users, type LucideIcon } from "lucide-react"
import { useLocale, useTranslations } from "next-intl"

import LocaleToggle from "@/components/LocaleToggle"
import BrandMark from "@/components/public/BrandMark"
import ThemeToggle from "@/components/ThemeToggle"
import { APP_NAME, APP_VERSION_LABEL } from "@/lib/app-info"
import { signOutAndClear } from "@/lib/firebase"
import { Link, usePathname } from "@/lib/i18n"

type Item = { href: string; key: string; icon: LucideIcon }

const items: Item[] = [
  { href: "/admin", key: "overview", icon: LayoutGrid },
  { href: "/admin#users", key: "users", icon: Users },
  { href: "/admin#versions", key: "versionControl", icon: PackageCheck },
  { href: "/admin#audit", key: "auditLog", icon: ScrollText },
]

export default function AdminShell({ user, children }: { user: User | null; children: ReactNode }) {
  const pathname = usePathname()
  const t = useTranslations()
  const locale = useLocale()
  const [menuOpen, setMenuOpen] = useState(false)
  const menuRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!menuOpen) return
    const close = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) setMenuOpen(false)
    }
    document.addEventListener("mousedown", close)
    return () => document.removeEventListener("mousedown", close)
  }, [menuOpen])

  const handleSignOut = async () => {
    setMenuOpen(false)
    await signOutAndClear()
    // Full page load: the Firestore instance is terminated after clearing its cache.
    window.location.replace(`/${locale}/login`)
  }

  const isActive = (href: string) => href === "/admin" && pathname === "/admin"

  return (
    <div className="flex min-h-dvh" style={{ backgroundColor: "var(--bg)", color: "var(--text-primary)" }}>
      <aside className="sticky top-0 hidden h-dvh w-56 shrink-0 flex-col border-r lg:flex" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
        <Link href="/admin" className="flex h-14 items-center gap-2 border-b px-5 text-sm font-semibold" style={{ borderColor: "var(--border)", color: "var(--text-primary)" }}>
          <BrandMark dark />
          {APP_NAME}
        </Link>
        <p className="border-b px-5 py-3 text-[11px] font-medium uppercase tracking-[0.08em]" style={{ borderColor: "var(--border)", color: "var(--text-muted)" }}>
          {t("admin.workspace")}
        </p>
        <nav className="flex-1 space-y-0.5 px-3 py-3">
          {items.map(({ href, key, icon: Icon }) => {
            const active = isActive(href)
            return (
              <Link
                key={href}
                href={href}
                aria-current={active ? "page" : undefined}
                className="nav-link flex items-center gap-2.5 rounded-md px-2.5 py-2 text-sm"
                style={{ color: active ? "var(--text-primary)" : "var(--text-secondary)", backgroundColor: active ? "var(--surface-soft)" : undefined, fontWeight: active ? 600 : 400 }}
              >
                <Icon size={16} strokeWidth={active ? 2.2 : 1.8} style={{ color: active ? "var(--primary)" : undefined }} />
                {t(`admin.${key}`)}
              </Link>
            )
          })}
        </nav>
        <p className="border-t px-5 py-3 text-[11px]" style={{ borderColor: "var(--border)", color: "var(--text-muted)" }}>v{APP_VERSION_LABEL}</p>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="sticky top-0 z-30 border-b" style={{ backgroundColor: "var(--bg)", borderColor: "var(--border)" }}>
          <div className="mx-auto flex h-14 max-w-[1200px] items-center justify-between gap-3 px-4 sm:px-6">
            <nav className="flex items-center gap-4 text-sm lg:hidden">
              {items.map(({ href, key }) => (
                <Link key={href} href={href} style={{ color: isActive(href) ? "var(--text-primary)" : "var(--text-muted)", fontWeight: isActive(href) ? 600 : 400 }}>
                  {t(`admin.${key}`)}
                </Link>
              ))}
            </nav>
            <span className="hidden text-xs lg:block" style={{ color: "var(--text-muted)" }}>{t("admin.title")}</span>

            <div className="flex items-center gap-2" ref={menuRef}>
              <div className="hidden items-center gap-2 sm:flex">
                <LocaleToggle />
                <ThemeToggle />
              </div>
              <div className="relative">
                <button type="button" onClick={() => setMenuOpen((v) => !v)} aria-expanded={menuOpen} aria-haspopup="menu" className="flex h-8 items-center gap-2 rounded-md pl-1 pr-2 text-sm" style={{ color: "var(--text-secondary)" }}>
                  <span className="flex h-6 w-6 items-center justify-center rounded-full text-xs font-semibold text-white" style={{ backgroundColor: "var(--primary)" }}>
                    {(user?.email || "A").charAt(0).toUpperCase()}
                  </span>
                  <span className="hidden max-w-[180px] truncate md:block">{user?.email}</span>
                  <ChevronDown size={14} />
                </button>
                {menuOpen && (
                  <div role="menu" className="absolute right-0 mt-1 w-56 overflow-hidden rounded-lg border text-sm" style={{ backgroundColor: "var(--bg-card)", borderColor: "var(--border)" }}>
                    <Link href="/dashboard" role="menuitem" onClick={() => setMenuOpen(false)} className="menu-item">
                      <LayoutGrid size={15} /> {t("admin.userDashboard")}
                    </Link>
                    <button type="button" role="menuitem" onClick={handleSignOut} className="menu-item w-full" style={{ color: "var(--expense)" }}>
                      <LogOut size={15} /> {t("common.signOut")}
                    </button>
                  </div>
                )}
              </div>
            </div>
          </div>
        </header>

        <main className="flex-1">
          <div className="mx-auto max-w-[1200px] px-4 py-6 sm:px-6">{children}</div>
        </main>
      </div>
    </div>
  )
}

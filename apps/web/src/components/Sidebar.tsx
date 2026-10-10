"use client"

import { ArrowLeftRight, BarChart3, HandCoins, LayoutGrid, PiggyBank, type LucideIcon } from "lucide-react"
import { useTranslations } from "next-intl"

import BrandMark from "@/components/public/BrandMark"
import { useFamilyData } from "@/lib/family-data"
import { APP_NAME, APP_VERSION_LABEL } from "@/lib/app-info"
import { Link, usePathname } from "@/lib/i18n"

type NavItem = { href: string; key: string; icon: LucideIcon }

export const navItems: NavItem[] = [
  { href: "/dashboard", key: "overview", icon: LayoutGrid },
  { href: "/dashboard/transactions", key: "transactions", icon: ArrowLeftRight },
  { href: "/dashboard/budget-savings", key: "budget", icon: PiggyBank },
  { href: "/dashboard/debts", key: "debts", icon: HandCoins },
  { href: "/dashboard/reports", key: "reports", icon: BarChart3 },
]

function useIsActive() {
  const pathname = usePathname()
  return (href: string) => (href === "/dashboard" ? pathname === href : pathname === href || pathname.startsWith(`${href}/`))
}

export default function Sidebar() {
  const t = useTranslations("dash")
  const isActive = useIsActive()
  const { scope, familyName } = useFamilyData()

  return (
    <aside className="sticky top-0 hidden h-dvh w-56 shrink-0 flex-col border-r lg:flex" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
      <Link href="/dashboard" className="flex h-14 items-center gap-2 border-b px-5 text-sm font-semibold" style={{ borderColor: "var(--border)", color: "var(--text-primary)" }}>
        <BrandMark dark />
        {APP_NAME}
      </Link>

      <div className="border-b px-5 py-3" style={{ borderColor: "var(--border)" }}>
        <p className="text-[11px] font-medium uppercase tracking-[0.08em]" style={{ color: "var(--text-muted)" }}>
          {scope === "family" ? t("scope.family") : t("scope.personal")}
        </p>
        <p className="mt-0.5 truncate text-sm font-medium" style={{ color: "var(--text-primary)" }}>
          {scope === "family" ? familyName || "—" : t("scope.personalName")}
        </p>
      </div>

      <nav className="flex-1 space-y-0.5 px-3 py-3" aria-label={t("nav.label")}>
        {navItems.map(({ href, key, icon: Icon }) => {
          const active = isActive(href)
          return (
            <Link
              key={href}
              href={href}
              aria-current={active ? "page" : undefined}
              className="nav-link flex items-center gap-2.5 rounded-md px-2.5 py-2 text-sm"
              style={{
                color: active ? "var(--text-primary)" : "var(--text-secondary)",
                backgroundColor: active ? "var(--surface-soft)" : undefined,
                fontWeight: active ? 600 : 400,
              }}
            >
              <Icon size={16} strokeWidth={active ? 2.2 : 1.8} style={{ color: active ? "var(--primary)" : undefined }} />
              {t(`nav.${key}`)}
            </Link>
          )
        })}
      </nav>

      <p className="border-t px-5 py-3 text-[11px]" style={{ borderColor: "var(--border)", color: "var(--text-muted)" }}>
        v{APP_VERSION_LABEL}
      </p>
    </aside>
  )
}

export function MobileNav() {
  const t = useTranslations("dash")
  const isActive = useIsActive()

  return (
    <nav
      className="fixed inset-x-0 bottom-0 z-40 grid grid-cols-5 border-t lg:hidden"
      style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)", paddingBottom: "env(safe-area-inset-bottom)" }}
      aria-label={t("nav.label")}
    >
      {navItems.map(({ href, key, icon: Icon }) => {
        const active = isActive(href)
        return (
          <Link
            key={href}
            href={href}
            aria-current={active ? "page" : undefined}
            className="flex flex-col items-center gap-1 py-2 text-[11px]"
            style={{ color: active ? "var(--primary)" : "var(--text-muted)", fontWeight: active ? 600 : 400 }}
          >
            <Icon size={18} strokeWidth={active ? 2.2 : 1.8} />
            {t(`navShort.${key}`)}
          </Link>
        )
      })}
    </nav>
  )
}

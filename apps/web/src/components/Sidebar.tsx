"use client"

import { usePathname } from "next/navigation"
import Link from "next/link"
import { useTranslations } from "next-intl"
import { User } from "firebase/auth"
import { APP_NAME, APP_VERSION_LABEL } from "@/lib/app-info"

interface NavSection {
  labelKey: string
  items: { href: string; labelKey: string; icon: string }[]
}

const sections: NavSection[] = [
  {
    labelKey: "sidebar.overview",
    items: [
      { href: "/dashboard", labelKey: "nav.dashboard", icon: "📊" },
    ],
  },
  {
    labelKey: "sidebar.finance",
    items: [
      { href: "/dashboard/wallets", labelKey: "nav.wallets", icon: "👛" },
      { href: "/dashboard/transactions", labelKey: "nav.transactions", icon: "💰" },
      { href: "/dashboard/debts", labelKey: "nav.debts", icon: "📋" },
    ],
  },
  {
    labelKey: "sidebar.planning",
    items: [
      { href: "/dashboard/budget-savings", labelKey: "nav.budgetSavings", icon: "🎯" },
      { href: "/dashboard/reports", labelKey: "nav.reports", icon: "📈" },
    ],
  },
  {
    labelKey: "sidebar.help",
    items: [
      { href: "/dashboard/guide", labelKey: "nav.guide", icon: "📖" },
    ],
  },
]

interface SidebarProps {
  user: User | null
  role: string | null
  isOpen: boolean
  onClose: () => void
}

export default function Sidebar({ user, role, isOpen, onClose }: SidebarProps) {
  const t = useTranslations()
  const pathname = usePathname()

  return (
    <>
      {isOpen && (
        <div className="fixed inset-0 z-40 bg-black/30 backdrop-blur-sm lg:hidden" onClick={onClose} />
      )}

      <aside
        className={`fixed top-0 left-0 z-50 flex h-full w-64 flex-col border-r transition-transform duration-300 lg:translate-x-0 lg:static lg:z-auto ${isOpen ? "translate-x-0" : "-translate-x-full"}`}
        style={{ backgroundColor: "var(--bg-card)", borderColor: "var(--border)", height: "100dvh" }}
      >
        {/* Logo */}
        <div className="flex h-16 items-center border-b px-6" style={{ borderColor: "var(--border)" }}>
          <Link href="/dashboard" className="text-xl font-bold tracking-tight" style={{ color: "var(--primary)" }}>
            {APP_NAME}
          </Link>
        </div>

        {/* Nav */}
        <nav className="flex-1 overflow-y-auto px-3 py-4 space-y-5">
          {sections.map((section) => (
            <div key={section.labelKey}>
              <p className="px-3 pb-1 text-[10px] font-semibold uppercase tracking-widest" style={{ color: "var(--text-muted)" }}>
                {t(section.labelKey)}
              </p>
              <div className="space-y-0.5">
                {section.items.map((item) => {
                  const isActive = pathname === item.href || pathname.startsWith(item.href + "/")
                  return (
                    <Link
                      key={item.href}
                      href={item.href}
                      onClick={onClose}
                      className="flex items-center gap-3 rounded-xl px-4 py-2.5 text-sm font-medium transition-all duration-200"
                      style={{
                        backgroundColor: isActive ? "var(--primary-bg)" : "transparent",
                        color: isActive ? "var(--primary)" : "var(--text-secondary)",
                      }}
                      onMouseEnter={(e) => { if (!isActive) { e.currentTarget.style.backgroundColor = "var(--surface-soft)" } }}
                      onMouseLeave={(e) => { if (!isActive) { e.currentTarget.style.backgroundColor = "transparent" } }}
                    >
                      <span className="text-base">{item.icon}</span>
                      {t(item.labelKey)}
                    </Link>
                  )
                })}
              </div>
            </div>
          ))}
        </nav>

        {/* Footer */}
        <div className="border-t px-4 py-3" style={{ borderColor: "var(--border)" }}>
          <p className="text-[10px] text-center" style={{ color: "var(--text-muted)" }}>{APP_NAME} v{APP_VERSION_LABEL}</p>
        </div>
      </aside>
    </>
  )
}

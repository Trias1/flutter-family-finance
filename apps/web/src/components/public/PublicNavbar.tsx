"use client"

import { useState } from "react"
import { Menu, X } from "lucide-react"
import { useTranslations } from "next-intl"

import BrandMark from "@/components/public/BrandMark"
import PublicTheme from "@/components/public/PublicTheme"
import LocaleToggle from "@/components/LocaleToggle"
import { APP_NAME } from "@/lib/app-info"
import { Link } from "@/lib/i18n"

export default function PublicNavbar() {
  const [open, setOpen] = useState(false)
  const t = useTranslations()
  const navItems = [
    { key: "features", label: t("publicNav.features"), href: { pathname: "/", hash: "features" } },
    { key: "guide", label: t("publicNav.docs"), href: { pathname: "/guide" } },
    { key: "download", label: t("nav.download"), href: { pathname: "/guide", hash: "download" } },
  ]

  return (
    <header className="absolute inset-x-0 top-0 z-30 border-b" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg)" }}>
      <PublicTheme />
      <div className="mx-auto flex h-14 max-w-6xl items-center justify-between gap-4 px-5 sm:px-8">
        <Link href="/" className="flex items-center gap-2 text-sm font-semibold" style={{ color: "var(--text-primary)" }}>
          <BrandMark dark />
          <span>{APP_NAME}</span>
        </Link>

        <nav className="hidden items-center gap-6 md:flex">
          {navItems.map((item) => (
            <Link key={item.key} href={item.href} className="text-sm hover:underline" style={{ color: "var(--text-secondary)" }}>
              {item.label}
            </Link>
          ))}
        </nav>

        <div className="hidden items-center gap-4 md:flex">
          <LocaleToggle />
          <Link href="/login" className="text-sm font-medium" style={{ color: "var(--text-primary)" }}>
            {t("publicNav.logIn")}
          </Link>
          <Link href="/login?register=1" className="rounded-md px-4 py-2 text-sm font-semibold text-white" style={{ backgroundColor: "var(--primary)" }}>
            {t("publicNav.signUp")}
          </Link>
        </div>

        <button type="button" onClick={() => setOpen((value) => !value)} className="flex h-9 w-9 items-center justify-center rounded-md md:hidden" style={{ color: "var(--text-primary)" }} aria-label={t("publicNav.toggleMenu")} aria-expanded={open}>
          {open ? <X size={18} /> : <Menu size={18} />}
        </button>
      </div>

      {open && (
        <div className="border-t px-5 py-3 md:hidden" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg)" }}>
          {navItems.map((item) => (
            <Link key={item.key} href={item.href} onClick={() => setOpen(false)} className="block py-2.5 text-sm" style={{ color: "var(--text-secondary)" }}>
              {item.label}
            </Link>
          ))}
          <div className="py-2.5"><LocaleToggle /></div>
          <div className="mt-2 grid grid-cols-2 gap-2">
            <Link href="/login" onClick={() => setOpen(false)} className="rounded-md border px-4 py-2.5 text-center text-sm font-medium" style={{ borderColor: "var(--border)", color: "var(--text-primary)" }}>
              {t("publicNav.logIn")}
            </Link>
            <Link href="/login?register=1" onClick={() => setOpen(false)} className="rounded-md px-4 py-2.5 text-center text-sm font-semibold text-white" style={{ backgroundColor: "var(--primary)" }}>
              {t("publicNav.signUp")}
            </Link>
          </div>
        </div>
      )}
    </header>
  )
}

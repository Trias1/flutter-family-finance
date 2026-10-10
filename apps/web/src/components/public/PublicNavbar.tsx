"use client"

import { useState } from "react"
import { Menu, X } from "lucide-react"
import { useTranslations } from "next-intl"

import BrandMark from "@/components/public/BrandMark"
import LocaleToggle from "@/components/LocaleToggle"
import { APP_NAME } from "@/lib/app-info"
import { Link } from "@/lib/i18n"

export default function PublicNavbar() {
  const [open, setOpen] = useState(false)
  const t = useTranslations()
  const navItems = [
    { label: t("publicNav.features"), href: "/#features" },
    { label: t("publicNav.pricing"), href: "/guide#download" },
    { label: t("publicNav.docs"), href: "/guide" },
    { label: t("publicNav.community"), href: "/login?register=1" },
  ]

  return (
    <>
      <div className="absolute left-1/2 top-6 z-30 w-[calc(100%-24px)] max-w-[880px] -translate-x-1/2 px-3 sm:px-0">
        <div className="rounded-full px-5 py-2 backdrop-blur-md glass-card">
          <div className="flex items-center justify-between gap-4">
            <Link href="/" className="flex items-center gap-2.5 text-[15px] font-bold" style={{ color: "var(--text-primary)" }}>
              <BrandMark dark />
              <span>{APP_NAME}</span>
            </Link>

            <nav className="hidden items-center gap-7 md:flex">
              {navItems.map((item) => (
                <a key={item.label} href={item.href} className="text-[13px] font-semibold transition-opacity hover:opacity-70" style={{ color: "var(--text-secondary)" }}>
                  {item.label}
                </a>
              ))}
            </nav>

            <div className="hidden items-center gap-2 md:flex">
              <LocaleToggle />
              <Link href="/login" className="text-[13px] font-semibold transition-opacity hover:opacity-70" style={{ color: "var(--text-primary)" }}>
                {t("publicNav.logIn")}
              </Link>
              <Link href="/login?register=1" className="rounded-full px-5 py-2 text-[13px] font-bold text-white transition-transform hover:scale-[1.02]" style={{ backgroundColor: "var(--primary)" }}>
                {t("publicNav.signUp")}
              </Link>
            </div>

            <button type="button" onClick={() => setOpen((value) => !value)} className="flex h-9 w-9 items-center justify-center rounded-full transition-colors hover:bg-black/5 md:hidden" style={{ color: "var(--text-primary)" }} aria-label={t("publicNav.toggleMenu")}>
              {open ? <X size={18} /> : <Menu size={18} />}
            </button>
          </div>
        </div>
      </div>

      {open && (
        <div className="absolute left-1/2 top-24 z-30 w-[calc(100%-24px)] max-w-[880px] -translate-x-1/2 px-3 md:hidden">
          <div className="rounded-[1.5rem] p-4 backdrop-blur-md glass-card">
            <div className="space-y-2">
              {navItems.map((item) => (
                <a key={item.label} href={item.href} onClick={() => setOpen(false)} className="block rounded-2xl px-4 py-3 text-[13px] font-semibold transition-colors hover:bg-black/5" style={{ color: "var(--text-secondary)" }}>
                  {item.label}
                </a>
              ))}
              <div className="px-4 py-2">
                <LocaleToggle />
              </div>
              <Link href="/login?register=1" onClick={() => setOpen(false)} className="mt-2 block rounded-2xl px-4 py-3 text-center text-[13px] font-bold text-white" style={{ backgroundColor: "var(--primary)" }}>
                {t("publicNav.signUp")}
              </Link>
            </div>
          </div>
        </div>
      )}
    </>
  )
}


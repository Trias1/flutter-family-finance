"use client"

import { useLocale } from "next-intl"
import { usePathname, useRouter } from "@/lib/i18n"

export default function LocaleToggle() {
  const locale = useLocale()
  const pathname = usePathname()
  const router = useRouter()

  const toggle = () => {
    const next = locale === "en" ? "id" : "en"
    router.replace(pathname, { locale: next })
  }

  return (
    <button
      onClick={toggle}
      className="rounded-xl border px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.1em] transition-all hover:scale-[1.04]"
      style={{
        backgroundColor: "var(--bg-card)",
        borderColor: "var(--border)",
        color: "var(--text-secondary)",
      }}
      aria-label="Switch language"
    >
      {locale === "en" ? "ID" : "EN"}
    </button>
  )
}

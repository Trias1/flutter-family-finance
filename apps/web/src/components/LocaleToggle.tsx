"use client"

import { useLocale, useTranslations } from "next-intl"
import { useSearchParams } from "next/navigation"

import { usePathname, useRouter } from "@/lib/i18n"

const locales = ["id", "en"] as const

export default function LocaleToggle() {
  const locale = useLocale()
  const t = useTranslations("theme")
  const pathname = usePathname()
  const searchParams = useSearchParams()
  const router = useRouter()

  const choose = (next: (typeof locales)[number]) => {
    if (next === locale) return
    const query = searchParams.toString()
    router.replace(query ? `${pathname}?${query}` : pathname, { locale: next })
  }

  return (
    <div className="seg h-8" role="group" aria-label={t("language")}>
      {locales.map((l) => (
        <button key={l} type="button" aria-pressed={locale === l} onClick={() => choose(l)} className="!px-2.5 !py-0 text-xs uppercase">
          {l}
        </button>
      ))}
    </div>
  )
}

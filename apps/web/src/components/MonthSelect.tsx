"use client"

import { useLocale, useTranslations } from "next-intl"

/** How far back the month pickers go; older months are loaded on demand. */
export const MONTHS_BACK = 24

/** Picks a month as an offset from `now` (0 = this month, -1 = last month, …). */
export default function MonthSelect({ value, onChange, now, className = "field" }: { value: number; onChange: (offset: number) => void; now: Date; className?: string }) {
  const t = useTranslations("dash")
  const locale = useLocale()
  const fmt = new Intl.DateTimeFormat(locale, { month: "long", year: "numeric" })
  return (
    <select value={value} onChange={(e) => onChange(Number(e.target.value))} className={className} aria-label={t("transactions.month")}>
      {Array.from({ length: MONTHS_BACK }, (_, i) => -i).map((o) => (
        <option key={o} value={o}>{fmt.format(new Date(now.getFullYear(), now.getMonth() + o, 1))}</option>
      ))}
    </select>
  )
}

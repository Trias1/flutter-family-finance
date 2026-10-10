"use client"

import { useTranslations } from "next-intl"

import { PageHeader } from "@/components/ui"

const steps = [
  { n: 1, details: 3 },
  { n: 2, details: 4 },
  { n: 3, details: 4 },
  { n: 4, details: 4 },
  { n: 5, details: 4 },
  { n: 6, details: 4 },
  { n: 7, details: 4 },
  { n: 8, details: 4 },
]

export default function DashboardGuidePage() {
  const t = useTranslations("guide")

  return (
    <div className="max-w-3xl">
      <PageHeader title={t("title")} description={t("desc")} />
      <ol className="rounded-lg border" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
        {steps.map(({ n, details }) => (
          <li key={n} className="grid gap-x-5 gap-y-1 border-b px-5 py-5 last:border-b-0 sm:grid-cols-[32px_1fr]" style={{ borderColor: "var(--border)" }}>
            <span className="text-sm tabular-nums" style={{ color: "var(--text-muted)" }}>{String(n).padStart(2, "0")}</span>
            <div>
              <h2 className="text-sm font-semibold" style={{ color: "var(--text-primary)" }}>{t(`step${n}Title`)}</h2>
              <p className="mt-1 text-sm leading-6" style={{ color: "var(--text-secondary)" }}>{t(`step${n}Desc`)}</p>
              <ul className="mt-2 list-disc space-y-1 pl-5 text-sm leading-6" style={{ color: "var(--text-secondary)" }}>
                {Array.from({ length: details }, (_, i) => <li key={i}>{t(`step${n}Detail${i + 1}`)}</li>)}
              </ul>
            </div>
          </li>
        ))}
      </ol>
    </div>
  )
}

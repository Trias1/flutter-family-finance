import { getLocale, getTranslations } from "next-intl/server"

import { formatRupiah } from "@/lib/money"

// Static sample of the dashboard's monthly summary, used on public pages.
// Figures are illustrative; the header says so.

const rows = [
  { key: "salary", category: "income", amount: 9_500_000 },
  { key: "groceries", category: "household", amount: -1_240_000 },
  { key: "electricity", category: "bills", amount: -386_500 },
  { key: "school", category: "education", amount: -750_000 },
  { key: "gold", category: "savings", amount: -1_000_000 },
] as const

const budgets = [
  { key: "household", used: 2_870_000, limit: 3_500_000 },
  { key: "transport", used: 610_000, limit: 800_000 },
  { key: "dining", used: 455_000, limit: 500_000 },
] as const

export default async function AppPhonePreview({ className = "" }: { className?: string }) {
  const t = await getTranslations("home.preview")
  const locale = await getLocale()
  const month = new Intl.DateTimeFormat(locale, { month: "long" }).format(new Date())

  return (
    <figure className={`overflow-hidden rounded-lg border text-left ${className}`} style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
      <div className="flex items-baseline justify-between border-b px-4 py-3" style={{ borderColor: "var(--border)" }}>
        <span className="text-xs font-semibold uppercase tracking-[0.12em]" style={{ color: "var(--text-muted)" }}>{month}</span>
        <span className="text-xs" style={{ color: "var(--text-muted)" }}>{t("sample")}</span>
      </div>

      <dl className="grid grid-cols-2 border-b" style={{ borderColor: "var(--border)" }}>
        <div className="border-r px-4 py-3" style={{ borderColor: "var(--border)" }}>
          <dt className="text-xs" style={{ color: "var(--text-muted)" }}>{t("income")}</dt>
          <dd className="mt-1 text-sm font-semibold tabular-nums" style={{ color: "var(--income)" }}>{formatRupiah(9_500_000)}</dd>
        </div>
        <div className="px-4 py-3">
          <dt className="text-xs" style={{ color: "var(--text-muted)" }}>{t("expense")}</dt>
          <dd className="mt-1 text-sm font-semibold tabular-nums" style={{ color: "var(--expense)" }}>{formatRupiah(3_376_500)}</dd>
        </div>
      </dl>

      <ul>
        {rows.map((row) => (
          <li key={row.key} className="flex items-center justify-between border-b px-4 py-2.5" style={{ borderColor: "var(--border)" }}>
            <div>
              <p className="text-sm" style={{ color: "var(--text-primary)" }}>{t(`rows.${row.key}`)}</p>
              <p className="text-xs" style={{ color: "var(--text-muted)" }}>{t(`categories.${row.category}`)}</p>
            </div>
            <span className="text-sm tabular-nums" style={{ color: row.amount > 0 ? "var(--income)" : "var(--text-primary)" }}>
              {row.amount > 0 ? "+" : ""}{formatRupiah(row.amount)}
            </span>
          </li>
        ))}
      </ul>

      <div className="space-y-3 px-4 py-4">
        {budgets.map((budget) => {
          const pct = Math.round((budget.used / budget.limit) * 100)
          return (
            <div key={budget.key}>
              <div className="flex justify-between text-xs">
                <span style={{ color: "var(--text-secondary)" }}>{t(`categories.${budget.key}`)}</span>
                <span className="tabular-nums" style={{ color: pct >= 90 ? "var(--expense)" : "var(--text-muted)" }}>{pct}%</span>
              </div>
              <div className="mt-1.5 h-1 rounded-full" style={{ backgroundColor: "var(--surface-soft)" }}>
                <div className="h-1 rounded-full" style={{ width: `${pct}%`, backgroundColor: pct >= 90 ? "var(--expense)" : "var(--primary)" }} />
              </div>
            </div>
          )
        })}
      </div>
    </figure>
  )
}

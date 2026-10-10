"use client"

import { useMemo, useState } from "react"
import { useLocale, useTranslations } from "next-intl"

import CashflowChart from "@/components/CashflowChart"
import { EmptyState, Money, PageHeader, Section, Skeleton } from "@/components/ui"
import { useFamilyData } from "@/lib/family-data"
import { byCategory, cashflowSeries, change, monthTotals } from "@/lib/finance"

const ranges = [6, 12] as const

export default function ReportsPage() {
  const t = useTranslations("dash")
  const locale = useLocale()
  const data = useFamilyData()
  const [range, setRange] = useState<(typeof ranges)[number]>(6)
  const [offset, setOffset] = useState(0)
  const [now] = useState(() => new Date())

  const view = useMemo(() => {
    const current = monthTotals(data.incomes, data.expenses, now, offset)
    const previous = monthTotals(data.incomes, data.expenses, now, offset - 1)
    const categories = byCategory(data.expenses, current.from, current.to)
    const prevCategories = new Map(byCategory(data.expenses, previous.from, previous.to).map((c) => [c.category, c.amount]))
    const series = cashflowSeries(data.incomes, data.expenses, now, range, locale)
    const months = Array.from({ length: range }, (_, i) => monthTotals(data.incomes, data.expenses, now, -i))
    return { current, previous, categories, prevCategories, series, months }
  }, [data.incomes, data.expenses, now, offset, range, locale])

  const monthFmt = new Intl.DateTimeFormat(locale, { month: "long", year: "numeric" })
  const shortFmt = new Intl.DateTimeFormat(locale, { month: "short", year: "numeric" })
  const savingRate = view.current.income > 0 ? (view.current.net / view.current.income) * 100 : null

  if (!data.ready) {
    return (
      <div className="space-y-6">
        <Skeleton className="h-7 w-48" />
        <Skeleton className="h-72 w-full" />
        <Skeleton className="h-64 w-full" />
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title={t("reports.title")}
        description={t("reports.desc")}
        actions={
          <div className="seg" role="group" aria-label={t("reports.range")}>
            {ranges.map((r) => (
              <button key={r} type="button" aria-pressed={range === r} onClick={() => setRange(r)}>{t("reports.months", { count: r })}</button>
            ))}
          </div>
        }
      />

      <Section title={t("overview.cashflow")} aside={t("reports.months", { count: range })}>
        <CashflowChart data={view.series} labels={{ income: t("overview.income"), expense: t("overview.expense"), net: t("common.net") }} height={260} emptyLabel={t("overview.noCashflow")} />
      </Section>

      <div className="grid gap-6 lg:grid-cols-5">
        <div className="lg:col-span-3">
          <Section
            title={t("reports.byCategory")}
            aside={
              <select value={offset} onChange={(e) => setOffset(Number(e.target.value))} className="field h-7 text-xs" aria-label={t("transactions.month")}>
                {Array.from({ length: 12 }, (_, i) => -i).map((o) => (
                  <option key={o} value={o}>{monthFmt.format(new Date(now.getFullYear(), now.getMonth() + o, 1))}</option>
                ))}
              </select>
            }
            flush
          >
            {view.categories.length === 0 ? (
              <EmptyState title={t("reports.noExpense")} />
            ) : (
              <ul>
                {view.categories.map((c) => {
                  const share = view.current.expense > 0 ? (c.amount / view.current.expense) * 100 : 0
                  const delta = change(c.amount, view.prevCategories.get(c.category) ?? 0)
                  return (
                    <li key={c.category} className="border-b px-5 py-3 last:border-b-0" style={{ borderColor: "var(--border)" }}>
                      <div className="flex items-baseline justify-between gap-3 text-sm">
                        <span className="truncate" style={{ color: "var(--text-primary)" }}>{c.category}</span>
                        <Money value={c.amount} className="shrink-0" />
                      </div>
                      <div className="mt-1.5 flex items-center gap-3">
                        <div className="h-1.5 flex-1 overflow-hidden rounded-full" style={{ backgroundColor: "var(--surface-soft)" }}>
                          <div className="h-full rounded-full" style={{ width: `${share}%`, backgroundColor: "var(--primary)" }} />
                        </div>
                        <span className="w-10 text-right text-xs tabular-nums" style={{ color: "var(--text-muted)" }}>{share.toFixed(0)}%</span>
                        <span className="w-14 text-right text-xs tabular-nums" style={{ color: delta === null ? "var(--text-muted)" : delta > 0 ? "var(--expense)" : "var(--income)" }}>
                          {delta === null ? t("reports.new") : `${delta > 0 ? "+" : ""}${delta.toFixed(0)}%`}
                        </span>
                      </div>
                    </li>
                  )
                })}
              </ul>
            )}
          </Section>
        </div>

        <div className="lg:col-span-2">
          <Section title={t("reports.summary")} aside={monthFmt.format(view.current.from)}>
            <dl className="space-y-3 text-sm">
              <Row label={t("overview.income")}><Money value={view.current.income} tone="income" /></Row>
              <Row label={t("overview.expense")}><Money value={view.current.expense} tone="expense" /></Row>
              <Row label={t("common.net")} strong><Money value={view.current.net} tone="auto" /></Row>
              <Row label={t("reports.savingRate")}>
                <span className="tabular-nums" style={{ color: "var(--text-primary)" }}>{savingRate === null ? "—" : `${savingRate.toFixed(0)}%`}</span>
              </Row>
              <Row label={t("reports.vsPrev")}>
                <Money value={view.current.expense - view.previous.expense} tone={view.current.expense > view.previous.expense ? "expense" : "income"} signed />
              </Row>
            </dl>
            <p className="mt-4 text-xs leading-5" style={{ color: "var(--text-muted)" }}>{t("reports.vsPrevNote")}</p>
          </Section>
        </div>
      </div>

      <Section title={t("reports.monthly")} flush>
        <div className="overflow-x-auto">
          <table className="w-full min-w-[520px] text-sm">
            <thead>
              <tr className="border-b text-left text-xs uppercase tracking-[0.06em]" style={{ borderColor: "var(--border)", color: "var(--text-muted)" }}>
                <th className="px-5 py-2.5 font-medium">{t("transactions.month")}</th>
                <th className="px-3 py-2.5 text-right font-medium">{t("overview.income")}</th>
                <th className="px-3 py-2.5 text-right font-medium">{t("overview.expense")}</th>
                <th className="px-5 py-2.5 text-right font-medium">{t("common.net")}</th>
              </tr>
            </thead>
            <tbody>
              {view.months.map((m) => (
                <tr key={m.from.toISOString()} className="data-row border-b last:border-b-0" style={{ borderColor: "var(--border)" }}>
                  <td className="px-5 py-2.5" style={{ color: "var(--text-primary)" }}>{shortFmt.format(m.from)}</td>
                  <td className="px-3 py-2.5 text-right"><Money value={m.income} tone={m.income ? "income" : "neutral"} /></td>
                  <td className="px-3 py-2.5 text-right"><Money value={m.expense} /></td>
                  <td className="px-5 py-2.5 text-right"><Money value={m.net} tone="auto" /></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Section>
    </div>
  )
}

function Row({ label, children, strong = false }: { label: string; children: React.ReactNode; strong?: boolean }) {
  return (
    <div className={`flex items-baseline justify-between gap-4 ${strong ? "border-t pt-3 font-semibold" : ""}`} style={{ borderColor: "var(--border)" }}>
      <dt style={{ color: "var(--text-secondary)" }}>{label}</dt>
      <dd>{children}</dd>
    </div>
  )
}

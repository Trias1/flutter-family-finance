"use client"

import { useMemo, useState } from "react"
import { useLocale, useTranslations } from "next-intl"

import { EmptyState, Money, PageHeader, ProgressBar, Section, Skeleton } from "@/components/ui"
import { useFamilyData } from "@/lib/family-data"
import { formatRupiah, monthKey } from "@/lib/money"

export default function BudgetSavingsPage() {
  const t = useTranslations("dash")
  const locale = useLocale()
  const data = useFamilyData()
  const [month, setMonth] = useState(() => monthKey(new Date()))

  const months = useMemo(() => {
    const keys = new Set(data.budgets.map((b) => b.month).filter(Boolean))
    keys.add(monthKey(new Date()))
    return Array.from(keys).sort().reverse()
  }, [data.budgets])

  const budgets = useMemo(
    () => data.budgets.filter((b) => b.month === month && b.budgetAmount > 0).sort((a, b) => b.usedAmount / b.budgetAmount - a.usedAmount / a.budgetAmount),
    [data.budgets, month],
  )
  const totals = budgets.reduce((acc, b) => ({ limit: acc.limit + b.budgetAmount, used: acc.used + b.usedAmount }), { limit: 0, used: 0 })

  const savings = useMemo(() => [...data.savings].sort((a, b) => b.currentAmount / (b.targetAmount || 1) - a.currentAmount / (a.targetAmount || 1)), [data.savings])
  const saved = savings.reduce((s, x) => s + x.currentAmount, 0)
  const target = savings.reduce((s, x) => s + x.targetAmount, 0)

  const monthLabel = (key: string) => {
    const [y, m] = key.split("-").map(Number)
    return new Intl.DateTimeFormat(locale, { month: "long", year: "numeric" }).format(new Date(y, m - 1, 1))
  }
  const dateFmt = new Intl.DateTimeFormat(locale, { month: "short", year: "numeric" })

  if (!data.ready) {
    return (
      <div className="space-y-6">
        <Skeleton className="h-7 w-48" />
        <Skeleton className="h-72 w-full" />
        <Skeleton className="h-56 w-full" />
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title={t("budget.title")}
        description={t("budget.desc")}
        actions={
          <select value={month} onChange={(e) => setMonth(e.target.value)} className="field" aria-label={t("transactions.month")}>
            {months.map((key) => <option key={key} value={key}>{monthLabel(key)}</option>)}
          </select>
        }
      />

      <Section
        title={t("budget.budgets")}
        aside={totals.limit > 0 ? <span><Money value={totals.used} /> / <Money value={totals.limit} /></span> : undefined}
        flush
      >
        {budgets.length === 0 ? (
          <EmptyState title={t("overview.noBudgetSet")} hint={t("overview.noBudgetHint")} />
        ) : (
          <>
            <div className="hidden grid-cols-[1.4fr_1fr_1fr_1fr] gap-4 border-b px-5 py-2.5 text-xs uppercase tracking-[0.06em] md:grid" style={{ borderColor: "var(--border)", color: "var(--text-muted)" }}>
              <span>{t("transactions.category")}</span>
              <span className="text-right">{t("budget.limit")}</span>
              <span className="text-right">{t("budget.used")}</span>
              <span className="text-right">{t("budget.left")}</span>
            </div>
            <ul>
              {budgets.map((b) => {
                const left = b.budgetAmount - b.usedAmount
                const pct = Math.round((b.usedAmount / b.budgetAmount) * 100)
                return (
                  <li key={b.id} className="border-b px-5 py-3.5 last:border-b-0" style={{ borderColor: "var(--border)" }}>
                    <div className="grid grid-cols-2 gap-x-4 gap-y-1 text-sm md:grid-cols-[1.4fr_1fr_1fr_1fr]">
                      <span className="flex items-baseline gap-2" style={{ color: "var(--text-primary)" }}>
                        {b.category}
                        <span className="text-xs tabular-nums" style={{ color: pct >= 100 ? "var(--expense)" : "var(--text-muted)" }}>{pct}%</span>
                      </span>
                      <span className="text-right md:block"><Money value={b.budgetAmount} /></span>
                      <span className="hidden text-right md:block"><Money value={b.usedAmount} /></span>
                      <span className="hidden text-right md:block"><Money value={left} tone="auto" /></span>
                    </div>
                    <div className="mt-2"><ProgressBar value={b.usedAmount} max={b.budgetAmount} /></div>
                    <p className="mt-1.5 text-xs md:hidden" style={{ color: "var(--text-muted)" }}>
                      {left >= 0 ? t("budget.leftShort", { amount: formatRupiah(left) }) : t("overview.overBy", { amount: formatRupiah(-left) })}
                    </p>
                  </li>
                )
              })}
            </ul>
          </>
        )}
      </Section>

      <Section
        title={t("budget.savings")}
        aside={target > 0 ? <span><Money value={saved} /> / <Money value={target} /></span> : undefined}
        flush
      >
        {savings.length === 0 ? (
          <EmptyState title={t("budget.noSavings")} hint={t("budget.noSavingsHint")} />
        ) : (
          <ul className="grid md:grid-cols-2">
            {savings.map((s, i) => {
              const pct = s.targetAmount > 0 ? Math.round((s.currentAmount / s.targetAmount) * 100) : 0
              return (
                <li
                  key={s.id}
                  className={`border-b px-5 py-4 ${i % 2 === 0 ? "md:border-r" : ""}`}
                  style={{ borderColor: "var(--border)" }}
                >
                  <div className="flex items-baseline justify-between gap-3">
                    <p className="truncate text-sm font-medium" style={{ color: "var(--text-primary)" }}>{s.name}</p>
                    <span className="text-xs tabular-nums" style={{ color: pct >= 100 ? "var(--income)" : "var(--text-muted)" }}>{pct}%</span>
                  </div>
                  <p className="mt-1 text-sm"><Money value={s.currentAmount} /> <span style={{ color: "var(--text-muted)" }}>/ </span><Money value={s.targetAmount} className="opacity-70" /></p>
                  <div className="mt-2.5"><ProgressBar value={s.currentAmount} max={s.targetAmount} kind="goal" /></div>
                  <p className="mt-1.5 text-xs" style={{ color: "var(--text-muted)" }}>
                    {[
                      s.goldGrams !== null ? t("budget.grams", { grams: s.goldGrams.toLocaleString(locale) }) : null,
                      s.targetDate ? t("budget.target", { date: dateFmt.format(s.targetDate) }) : null,
                    ].filter(Boolean).join(" · ")}
                  </p>
                </li>
              )
            })}
          </ul>
        )}
      </Section>
    </div>
  )
}

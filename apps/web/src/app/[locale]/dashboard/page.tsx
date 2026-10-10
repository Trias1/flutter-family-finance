"use client"

import { useMemo, useState } from "react"
import { useLocale, useTranslations } from "next-intl"

import CashflowChart from "@/components/CashflowChart"
import { EmptyState, Money, PageHeader, ProgressBar, Section, Skeleton, Stat, StatStrip } from "@/components/ui"
import { useFamilyData } from "@/lib/family-data"
import { budgetsForMonth, cashflowSeries, change, monthTotals } from "@/lib/finance"
import { Link } from "@/lib/i18n"
import { formatRupiah } from "@/lib/money"

function ChangeNote({ value, invert = false, label, noCompare }: { value: number | null; invert?: boolean; label: string; noCompare: string }) {
  if (value === null) return <>{noCompare}</>
  const up = value >= 0
  const good = invert ? !up : up
  return (
    <>
      <span style={{ color: good ? "var(--income)" : "var(--expense)" }}>{up ? "▲" : "▼"} {Math.abs(value).toFixed(0)}%</span> {label}
    </>
  )
}

export default function OverviewPage() {
  const t = useTranslations("dash")
  const locale = useLocale()
  const data = useFamilyData()
  const [now] = useState(() => new Date())

  const view = useMemo(() => {
    const current = monthTotals(data.incomes, data.expenses, now)
    const previous = monthTotals(data.incomes, data.expenses, now, -1)
    const budgets = budgetsForMonth(data.budgets, now)
    const budgetLimit = budgets.reduce((s, b) => s + b.budgetAmount, 0)
    const budgetUsed = budgets.reduce((s, b) => s + b.usedAmount, 0)
    const watch = budgets
      .map((b) => ({ ...b, ratio: b.usedAmount / b.budgetAmount }))
      .sort((a, b) => b.ratio - a.ratio)
      .slice(0, 5)
    const recent = [...data.incomes, ...data.expenses].sort((a, b) => b.date.getTime() - a.date.getTime()).slice(0, 8)
    const soon = new Date(now.getTime() + 14 * 86_400_000)
    const bills = data.bills
      .filter((b) => b.status !== "paid" && b.dueDate && b.dueDate <= soon)
      .sort((a, b) => (a.dueDate?.getTime() ?? 0) - (b.dueDate?.getTime() ?? 0))
      .slice(0, 5)
    return {
      current,
      incomeChange: change(current.income, previous.income),
      expenseChange: change(current.expense, previous.expense),
      budgetLimit,
      budgetUsed,
      watch,
      recent,
      bills,
      series: cashflowSeries(data.incomes, data.expenses, now, 6, locale),
    }
  }, [data.incomes, data.expenses, data.budgets, data.bills, now, locale])

  const monthName = new Intl.DateTimeFormat(locale, { month: "long", year: "numeric" }).format(now)
  const dateFmt = new Intl.DateTimeFormat(locale, { day: "numeric", month: "short" })

  if (!data.ready) {
    return (
      <div className="space-y-6">
        <Skeleton className="h-7 w-48" />
        <Skeleton className="h-[106px] w-full" />
        <div className="grid gap-6 lg:grid-cols-3">
          <Skeleton className="h-72 lg:col-span-2" />
          <Skeleton className="h-72" />
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <PageHeader title={t("overview.title")} description={monthName} />

      {data.scope === "personal" && (
        <p className="rounded-md border px-4 py-3 text-sm" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)", color: "var(--text-secondary)" }}>
          {t("overview.personalNotice")}
        </p>
      )}

      <StatStrip>
        <Stat label={t("overview.net")} value={view.current.net} tone="auto" note={t("overview.netNote")} />
        <Stat label={t("overview.income")} value={view.current.income} tone="income" note={<ChangeNote value={view.incomeChange} label={t("overview.vsLastMonth")} noCompare={t("overview.noCompare")} />} />
        <Stat label={t("overview.expense")} value={view.current.expense} tone="expense" note={<ChangeNote value={view.expenseChange} invert label={t("overview.vsLastMonth")} noCompare={t("overview.noCompare")} />} />
        <Stat
          label={t("overview.budgetLeft")}
          value={view.budgetLimit - view.budgetUsed}
          tone="auto"
          note={view.budgetLimit > 0 ? t("overview.ofBudget", { amount: formatRupiah(view.budgetLimit) }) : t("overview.noBudgetSet")}
        />
      </StatStrip>

      <div className="grid gap-6 lg:grid-cols-3">
        <div className="lg:col-span-2">
          <Section title={t("overview.cashflow")} aside={t("overview.last6Months")}>
            <CashflowChart data={view.series} labels={{ income: t("overview.income"), expense: t("overview.expense") }} emptyLabel={t("overview.noCashflow")} />
            <div className="mt-3 flex gap-4 text-xs" style={{ color: "var(--text-muted)" }}>
              <span className="flex items-center gap-1.5"><span className="h-2 w-2 rounded-sm" style={{ backgroundColor: "var(--chart-in)" }} />{t("overview.income")}</span>
              <span className="flex items-center gap-1.5"><span className="h-2 w-2 rounded-sm" style={{ backgroundColor: "var(--chart-out)" }} />{t("overview.expense")}</span>
            </div>
          </Section>
        </div>

        <Section title={t("overview.budgetWatch")} aside={<Link href="/dashboard/budget-savings" className="hover:underline">{t("common.seeAll")}</Link>} flush>
          {view.watch.length === 0 ? (
            <EmptyState title={t("overview.noBudgetSet")} hint={t("overview.noBudgetHint")} />
          ) : (
            <ul className="divide-y" style={{ borderColor: "var(--border)" }}>
              {view.watch.map((b) => (
                <li key={b.id} className="px-5 py-3.5" style={{ borderColor: "var(--border)" }}>
                  <div className="mb-2 flex items-baseline justify-between gap-3 text-sm">
                    <span className="truncate" style={{ color: "var(--text-primary)" }}>{b.category}</span>
                    <span className="shrink-0 text-xs tabular-nums" style={{ color: b.ratio >= 1 ? "var(--expense)" : "var(--text-muted)" }}>
                      {Math.round(b.ratio * 100)}%
                    </span>
                  </div>
                  <ProgressBar value={b.usedAmount} max={b.budgetAmount} />
                  <p className="mt-1.5 text-xs" style={{ color: "var(--text-muted)" }}>
                    {b.ratio >= 1
                      ? t("overview.overBy", { amount: formatRupiah(b.usedAmount - b.budgetAmount) })
                      : t("overview.leftOf", { left: formatRupiah(b.budgetAmount - b.usedAmount), total: formatRupiah(b.budgetAmount) })}
                  </p>
                </li>
              ))}
            </ul>
          )}
        </Section>
      </div>

      <div className="grid gap-6 lg:grid-cols-3">
        <div className="lg:col-span-2">
          <Section title={t("overview.recent")} aside={<Link href="/dashboard/transactions" className="hover:underline">{t("common.seeAll")}</Link>} flush>
            {view.recent.length === 0 ? (
              <EmptyState title={t("transactions.empty")} hint={t("transactions.emptyHint")} />
            ) : (
              <ul>
                {view.recent.map((tx) => {
                  const who = data.memberName(tx.userId)
                  return (
                    <li key={`${tx.kind}-${tx.id}`} className="data-row flex items-center gap-4 border-b px-5 py-3 last:border-b-0" style={{ borderColor: "var(--border)" }}>
                      <span className="w-12 shrink-0 text-xs tabular-nums" style={{ color: "var(--text-muted)" }}>{dateFmt.format(tx.date)}</span>
                      <div className="min-w-0 flex-1">
                        <p className="truncate text-sm" style={{ color: "var(--text-primary)" }}>{tx.category}</p>
                        <p className="truncate text-xs" style={{ color: "var(--text-muted)" }}>
                          {[tx.note, who].filter(Boolean).join(" · ") || (tx.kind === "income" ? t("common.income") : t("common.expense"))}
                        </p>
                      </div>
                      <Money value={tx.kind === "income" ? tx.amount : -tx.amount} tone={tx.kind === "income" ? "income" : "neutral"} signed className="shrink-0 text-sm" />
                    </li>
                  )
                })}
              </ul>
            )}
          </Section>
        </div>

        <Section title={t("overview.bills")} aside={t("overview.next14Days")} flush>
          {view.bills.length === 0 ? (
            <EmptyState title={t("overview.noBills")} />
          ) : (
            <ul>
              {view.bills.map((bill) => {
                const overdue = bill.dueDate !== null && bill.dueDate < now
                return (
                  <li key={bill.id} className="flex items-center justify-between gap-3 border-b px-5 py-3 last:border-b-0" style={{ borderColor: "var(--border)" }}>
                    <div className="min-w-0">
                      <p className="truncate text-sm" style={{ color: "var(--text-primary)" }}>{bill.name}</p>
                      <p className="text-xs" style={{ color: overdue ? "var(--expense)" : "var(--text-muted)" }}>
                        {overdue ? t("overview.overdue") : t("overview.due")} {bill.dueDate ? dateFmt.format(bill.dueDate) : ""}
                      </p>
                    </div>
                    <Money value={bill.amount} className="shrink-0 text-sm" />
                  </li>
                )
              })}
            </ul>
          )}
        </Section>
      </div>
    </div>
  )
}

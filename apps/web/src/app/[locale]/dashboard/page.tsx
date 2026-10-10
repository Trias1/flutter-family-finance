"use client"

import { useMemo, useState } from "react"
import { useLocale, useTranslations } from "next-intl"

import CashflowChart from "@/components/CashflowChart"
import DataError, { useFailed } from "@/components/DataError"
import MemberSpending from "@/components/MemberSpending"
import MonthSelect from "@/components/MonthSelect"
import { EmptyState, Money, PageHeader, ProgressBar, Section, Skeleton, Stat, StatStrip } from "@/components/ui"
import { useFamilyData } from "@/lib/family-data"
import { budgetsForMonth, byCategory, cashflowSeries, change, monthTotals, spending } from "@/lib/finance"
import { Link } from "@/lib/i18n"
import { formatRupiah, startOfMonth } from "@/lib/money"

const CHART_MONTHS = 6

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
  const [offset, setOffset] = useState(0)
  const txFailed = useFailed("incomes", "expenses")
  const budgetsFailed = useFailed("budgets")
  const billsFailed = useFailed("bills")
  const debtsFailed = useFailed("debts")

  const pickMonth = (o: number) => {
    setOffset(o)
    // The chart reaches back five months before the chosen one.
    data.loadOlder(-o + CHART_MONTHS - 1)
  }
  const covered = data.loadedFrom <= startOfMonth(now, offset - CHART_MONTHS + 1) && !data.loadingOlder

  const view = useMemo(() => {
    const ref = startOfMonth(now, offset)
    const current = monthTotals(data.incomes, data.expenses, ref)
    const previous = monthTotals(data.incomes, data.expenses, ref, -1)
    const budgets = budgetsForMonth(data.budgets, ref)
    const budgetLimit = budgets.reduce((s, b) => s + b.budgetAmount, 0)
    const budgetUsed = budgets.reduce((s, b) => s + b.usedAmount, 0)
    const watch = budgets
      .map((b) => ({ ...b, ratio: b.usedAmount / b.budgetAmount }))
      .sort((a, b) => b.ratio - a.ratio)
      .slice(0, 5)
    const prevCategories = new Map(byCategory(spending(data.expenses), previous.from, previous.to).map((c) => [c.category, c.amount]))
    const topCategories = byCategory(spending(data.expenses), current.from, current.to)
      .slice(0, 5)
      .map((c) => ({ ...c, delta: change(c.amount, prevCategories.get(c.category) ?? 0) }))
    const recent = [...data.incomes, ...data.expenses].sort((a, b) => b.date.getTime() - a.date.getTime()).slice(0, 8)
    const soon = new Date(now.getTime() + 14 * 86_400_000)
    const bills = data.bills
      .filter((b) => b.status !== "paid" && b.dueDate && b.dueDate <= soon)
      .sort((a, b) => (a.dueDate?.getTime() ?? 0) - (b.dueDate?.getTime() ?? 0))
      .slice(0, 5)
    const activeDebts = data.debts.filter((d) => d.status === "active")
    const nextDebt = activeDebts.filter((d) => d.dueDate).sort((a, b) => (a.dueDate?.getTime() ?? 0) - (b.dueDate?.getTime() ?? 0))[0] ?? null
    return {
      current,
      incomeChange: change(current.income, previous.income),
      expenseChange: change(current.expense, previous.expense),
      budgetLimit,
      budgetUsed,
      watch,
      topCategories,
      recent,
      bills,
      owe: activeDebts.filter((d) => d.type === "hutang").reduce((s, d) => s + d.remainingAmount, 0),
      owed: activeDebts.filter((d) => d.type === "piutang").reduce((s, d) => s + d.remainingAmount, 0),
      nextDebt,
      series: cashflowSeries(data.incomes, data.expenses, ref, CHART_MONTHS, locale),
      chartFrom: startOfMonth(ref, -(CHART_MONTHS - 1)),
    }
  }, [data.incomes, data.expenses, data.budgets, data.bills, data.debts, now, offset, locale])

  const monthFmt = new Intl.DateTimeFormat(locale, { month: "long", year: "numeric" })
  const shortFmt = new Intl.DateTimeFormat(locale, { month: "short", year: "numeric" })
  const dateFmt = new Intl.DateTimeFormat(locale, { day: "numeric", month: "short" })
  const monthName = monthFmt.format(view.current.from)
  const chartRange = `${shortFmt.format(view.chartFrom)} – ${shortFmt.format(view.current.from)}`

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
      <PageHeader title={t("overview.title")} description={monthName} actions={<MonthSelect value={offset} onChange={pickMonth} now={now} />} />

      {data.scope === "personal" && (
        <p className="rounded-md border px-4 py-3 text-sm" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)", color: "var(--text-secondary)" }}>
          {t("overview.personalNotice")}
        </p>
      )}

      {txFailed ? (
        <Section><DataError /></Section>
      ) : !covered ? (
        <Skeleton className="h-[106px] w-full" />
      ) : (
        <StatStrip>
          <Stat label={t("overview.net")} value={view.current.net} tone="auto" note={t("overview.netNote")} />
          <Stat label={t("overview.income")} value={view.current.income} tone="income" note={<ChangeNote value={view.incomeChange} label={t("overview.vsLastMonth")} noCompare={t("overview.noCompare")} />} />
          <Stat label={t("overview.expense")} value={view.current.expense} tone="expense" note={<ChangeNote value={view.expenseChange} invert label={t("overview.vsLastMonth")} noCompare={t("overview.noCompare")} />} />
          <Stat
            label={t("overview.budgetLeft")}
            value={view.budgetLimit - view.budgetUsed}
            tone="auto"
            note={budgetsFailed ? t("errors.loadFailed") : view.budgetLimit > 0 ? t("overview.ofBudget", { amount: formatRupiah(view.budgetLimit) }) : t("overview.noBudgetSet")}
          />
        </StatStrip>
      )}

      <div className="grid gap-6 lg:grid-cols-3">
        <div className="lg:col-span-2">
          <Section title={t("overview.cashflow")} aside={chartRange}>
            {txFailed ? (
              <DataError />
            ) : !covered ? (
              <Skeleton className="h-[240px] w-full" />
            ) : (
              <CashflowChart
                data={view.series}
                labels={{ income: t("overview.income"), expense: t("overview.expense"), net: t("common.net"), month: t("transactions.month"), caption: `${t("overview.cashflow")}, ${chartRange}` }}
                emptyLabel={t("overview.noCashflow")}
              />
            )}
          </Section>
        </div>

        <Section title={t("overview.budgetWatch")} aside={<Link href="/dashboard/budget-savings" className="hover:underline">{t("common.seeAll")}</Link>} flush>
          {budgetsFailed ? (
            <DataError />
          ) : view.watch.length === 0 ? (
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
                  <ProgressBar value={b.usedAmount} max={b.budgetAmount} label={b.category} />
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

      <div className={`grid gap-6 ${data.scope === "family" ? "lg:grid-cols-3" : "lg:grid-cols-2"}`}>
        <Section title={t("overview.topCategories")} aside={<Link href="/dashboard/reports" className="hover:underline">{t("common.seeAll")}</Link>} flush>
          {txFailed ? (
            <DataError />
          ) : !covered ? (
            <div className="space-y-3 p-5">{Array.from({ length: 4 }, (_, i) => <Skeleton key={i} className="h-6 w-full" />)}</div>
          ) : view.topCategories.length === 0 ? (
            <EmptyState title={t("reports.noExpense")} />
          ) : (
            <ul>
              {view.topCategories.map((c) => (
                <li key={c.category} className="flex items-baseline justify-between gap-3 border-b px-5 py-3 text-sm last:border-b-0" style={{ borderColor: "var(--border)" }}>
                  <span className="min-w-0 truncate" style={{ color: "var(--text-primary)" }}>{c.category}</span>
                  <span className="flex shrink-0 items-baseline gap-3">
                    <Money value={c.amount} />
                    <span className="w-12 text-right text-xs tabular-nums" style={{ color: c.delta === null ? "var(--text-muted)" : c.delta > 0 ? "var(--expense)" : "var(--income)" }}>
                      {c.delta === null ? t("reports.new") : `${c.delta > 0 ? "+" : ""}${c.delta.toFixed(0)}%`}
                    </span>
                  </span>
                </li>
              ))}
            </ul>
          )}
        </Section>

        {covered && <MemberSpending from={view.current.from} to={view.current.to} />}

        <Section title={t("overview.debts")} aside={<Link href="/dashboard/debts" className="hover:underline">{t("common.seeAll")}</Link>}>
          {debtsFailed ? (
            <DataError />
          ) : (
            <dl className="space-y-3 text-sm">
              <div className="flex items-baseline justify-between gap-4">
                <dt style={{ color: "var(--text-secondary)" }}>{t("debts.owe")}</dt>
                <dd><Money value={view.owe} tone={view.owe > 0 ? "expense" : "neutral"} /></dd>
              </div>
              <div className="flex items-baseline justify-between gap-4">
                <dt style={{ color: "var(--text-secondary)" }}>{t("debts.owed")}</dt>
                <dd><Money value={view.owed} tone={view.owed > 0 ? "income" : "neutral"} /></dd>
              </div>
              <div className="border-t pt-3" style={{ borderColor: "var(--border)" }}>
                <dt className="text-xs" style={{ color: "var(--text-muted)" }}>{t("overview.nextDue")}</dt>
                <dd className="mt-1">
                  {view.nextDebt?.dueDate ? (
                    <span className="flex items-baseline justify-between gap-3">
                      <span className="min-w-0 truncate" style={{ color: "var(--text-primary)" }}>
                        {view.nextDebt.personName || "—"}
                        <span className="ml-2 text-xs" style={{ color: view.nextDebt.dueDate < now ? "var(--expense)" : "var(--text-muted)" }}>
                          {view.nextDebt.dueDate < now ? t("overview.overdue") : t("overview.due")} {dateFmt.format(view.nextDebt.dueDate)}
                        </span>
                      </span>
                      <Money value={view.nextDebt.remainingAmount} className="shrink-0" />
                    </span>
                  ) : (
                    <span style={{ color: "var(--text-muted)" }}>{t("overview.noDebtsDue")}</span>
                  )}
                </dd>
              </div>
            </dl>
          )}
        </Section>
      </div>

      <div className="grid gap-6 lg:grid-cols-3">
        <div className="lg:col-span-2">
          <Section title={t("overview.recent")} aside={<Link href="/dashboard/transactions" className="hover:underline">{t("common.seeAll")}</Link>} flush>
            {txFailed ? (
              <DataError />
            ) : view.recent.length === 0 ? (
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
          {billsFailed ? (
            <DataError />
          ) : view.bills.length === 0 ? (
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

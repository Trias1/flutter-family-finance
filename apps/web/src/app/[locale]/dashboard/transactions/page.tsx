"use client"

import { useMemo, useState } from "react"
import { Search } from "lucide-react"
import { useLocale, useTranslations } from "next-intl"

import { EmptyState, Money, PageHeader, Section, Skeleton } from "@/components/ui"
import { useFamilyData, type Tx } from "@/lib/family-data"
import { monthKey } from "@/lib/money"

type Kind = "all" | "income" | "expense"
const pageSize = 50

export default function TransactionsPage() {
  const t = useTranslations("dash")
  const locale = useLocale()
  const data = useFamilyData()
  const [month, setMonth] = useState(() => monthKey(new Date()))
  const [kind, setKind] = useState<Kind>("all")
  const [category, setCategory] = useState("")
  const [search, setSearch] = useState("")
  const [limit, setLimit] = useState(pageSize)

  const all = useMemo(
    () => [...data.incomes, ...data.expenses].sort((a, b) => b.date.getTime() - a.date.getTime()),
    [data.incomes, data.expenses],
  )

  const months = useMemo(() => {
    const keys = new Set(all.map((tx) => monthKey(tx.date)))
    keys.add(monthKey(new Date()))
    return Array.from(keys).sort().reverse()
  }, [all])

  const inMonth = useMemo(() => (month === "all" ? all : all.filter((tx) => monthKey(tx.date) === month)), [all, month])
  const categories = useMemo(() => Array.from(new Set(inMonth.map((tx) => tx.category))).sort(), [inMonth])

  const rows = useMemo(() => {
    const q = search.trim().toLowerCase()
    return inMonth.filter((tx) => {
      if (kind !== "all" && tx.kind !== kind) return false
      if (category && tx.category !== category) return false
      if (!q) return true
      return [tx.category, tx.note, data.memberName(tx.userId)].some((v) => v.toLowerCase().includes(q))
    })
  }, [inMonth, kind, category, search, data])

  const totals = useMemo(() => {
    let income = 0
    let expense = 0
    for (const tx of rows) {
      if (tx.kind === "income") income += tx.amount
      else expense += tx.amount
    }
    return { income, expense }
  }, [rows])

  const monthLabel = (key: string) => {
    const [y, m] = key.split("-").map(Number)
    return new Intl.DateTimeFormat(locale, { month: "long", year: "numeric" }).format(new Date(y, m - 1, 1))
  }
  const dateFmt = new Intl.DateTimeFormat(locale, { day: "2-digit", month: "short", year: "numeric" })
  const visible = rows.slice(0, limit)
  const resetPaging = () => setLimit(pageSize)
  const signed = (tx: Tx) => (tx.kind === "income" ? tx.amount : -tx.amount)

  return (
    <div className="space-y-5">
      <PageHeader title={t("transactions.title")} description={t("transactions.desc")} />

      <div className="flex flex-col gap-3 lg:flex-row lg:items-center">
        <div className="relative flex-1">
          <Search size={15} className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2" style={{ color: "var(--text-muted)" }} />
          <input
            type="search"
            value={search}
            onChange={(e) => { setSearch(e.target.value); resetPaging() }}
            placeholder={t("transactions.search")}
            aria-label={t("transactions.search")}
            className="field w-full pl-9"
          />
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <select value={month} onChange={(e) => { setMonth(e.target.value); setCategory(""); resetPaging() }} className="field" aria-label={t("transactions.month")}>
            <option value="all">{t("transactions.allMonths")}</option>
            {months.map((key) => <option key={key} value={key}>{monthLabel(key)}</option>)}
          </select>
          <select value={category} onChange={(e) => { setCategory(e.target.value); resetPaging() }} className="field max-w-[180px]" aria-label={t("transactions.category")}>
            <option value="">{t("transactions.allCategories")}</option>
            {categories.map((c) => <option key={c} value={c}>{c}</option>)}
          </select>
          <div className="seg" role="group" aria-label={t("transactions.type")}>
            {(["all", "income", "expense"] as Kind[]).map((k) => (
              <button key={k} type="button" aria-pressed={kind === k} onClick={() => { setKind(k); resetPaging() }}>
                {k === "all" ? t("common.all") : k === "income" ? t("common.income") : t("common.expense")}
              </button>
            ))}
          </div>
        </div>
      </div>

      <div className="flex flex-wrap gap-x-6 gap-y-1 text-sm" style={{ color: "var(--text-secondary)" }}>
        <span>{t("transactions.count", { count: rows.length })}</span>
        <span>{t("common.income")} <Money value={totals.income} tone="income" /></span>
        <span>{t("common.expense")} <Money value={totals.expense} tone="expense" /></span>
        <span>Net <Money value={totals.income - totals.expense} tone="auto" /></span>
      </div>

      <Section flush>
        {!data.ready ? (
          <div className="space-y-3 p-5">{Array.from({ length: 6 }, (_, i) => <Skeleton key={i} className="h-9 w-full" />)}</div>
        ) : rows.length === 0 ? (
          <EmptyState title={all.length === 0 ? t("transactions.empty") : t("transactions.noMatch")} hint={all.length === 0 ? t("transactions.emptyHint") : undefined} />
        ) : (
          <>
            <table className="hidden w-full text-sm md:table">
              <thead>
                <tr className="border-b text-left text-xs uppercase tracking-[0.06em]" style={{ borderColor: "var(--border)", color: "var(--text-muted)" }}>
                  <th className="px-5 py-2.5 font-medium">{t("transactions.date")}</th>
                  <th className="px-3 py-2.5 font-medium">{t("transactions.category")}</th>
                  <th className="px-3 py-2.5 font-medium">{t("transactions.note")}</th>
                  {data.scope === "family" && <th className="px-3 py-2.5 font-medium">{t("transactions.by")}</th>}
                  <th className="px-5 py-2.5 text-right font-medium">{t("transactions.amount")}</th>
                </tr>
              </thead>
              <tbody>
                {visible.map((tx) => (
                  <tr key={`${tx.kind}-${tx.id}`} className="data-row border-b last:border-b-0" style={{ borderColor: "var(--border)" }}>
                    <td className="whitespace-nowrap px-5 py-2.5 text-xs tabular-nums" style={{ color: "var(--text-muted)" }}>{dateFmt.format(tx.date)}</td>
                    <td className="px-3 py-2.5" style={{ color: "var(--text-primary)" }}>{tx.category}</td>
                    <td className="max-w-[320px] truncate px-3 py-2.5" style={{ color: "var(--text-secondary)" }}>{tx.note || "—"}</td>
                    {data.scope === "family" && <td className="px-3 py-2.5" style={{ color: "var(--text-secondary)" }}>{data.memberName(tx.userId) || "—"}</td>}
                    <td className="whitespace-nowrap px-5 py-2.5 text-right"><Money value={signed(tx)} tone={tx.kind === "income" ? "income" : "neutral"} signed /></td>
                  </tr>
                ))}
              </tbody>
            </table>

            <ul className="md:hidden">
              {visible.map((tx) => (
                <li key={`${tx.kind}-${tx.id}`} className="flex items-center justify-between gap-3 border-b px-4 py-3 last:border-b-0" style={{ borderColor: "var(--border)" }}>
                  <div className="min-w-0">
                    <p className="truncate text-sm" style={{ color: "var(--text-primary)" }}>{tx.category}</p>
                    <p className="truncate text-xs" style={{ color: "var(--text-muted)" }}>
                      {[dateFmt.format(tx.date), tx.note, data.memberName(tx.userId)].filter(Boolean).join(" · ")}
                    </p>
                  </div>
                  <Money value={signed(tx)} tone={tx.kind === "income" ? "income" : "neutral"} signed className="shrink-0 text-sm" />
                </li>
              ))}
            </ul>

            {rows.length > limit && (
              <div className="border-t p-3 text-center" style={{ borderColor: "var(--border)" }}>
                <button type="button" onClick={() => setLimit((l) => l + pageSize)} className="text-sm font-medium" style={{ color: "var(--primary)" }}>
                  {t("transactions.showMore", { count: Math.min(pageSize, rows.length - limit) })}
                </button>
              </div>
            )}
          </>
        )}
      </Section>
    </div>
  )
}

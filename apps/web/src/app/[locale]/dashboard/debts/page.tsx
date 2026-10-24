"use client"

import { useMemo, useState } from "react"
import { useLocale, useTranslations } from "next-intl"

import DataError, { useFailed } from "@/components/DataError"
import { EmptyState, Money, PageHeader, Pill, ProgressBar, Section, Skeleton, Stat } from "@/components/ui"
import { useFamilyData, type Debt } from "@/lib/family-data"

type Filter = "active" | "paid" | "all"

export default function DebtsPage() {
  const t = useTranslations("dash")
  const locale = useLocale()
  const data = useFamilyData()
  const [filter, setFilter] = useState<Filter>("active")
  const [now] = useState(() => new Date())
  const failed = useFailed("debts")

  const { owe, owed, groups } = useMemo(() => {
    const active = data.debts.filter((d) => d.status === "active")
    const visible = data.debts
      .filter((d) => (filter === "all" ? true : filter === "paid" ? d.status === "paid" : d.status === "active"))
      .sort((a, b) => (a.dueDate?.getTime() ?? Infinity) - (b.dueDate?.getTime() ?? Infinity))
    return {
      owe: active.filter((d) => d.type === "hutang").reduce((s, d) => s + d.remainingAmount, 0),
      owed: active.filter((d) => d.type === "piutang").reduce((s, d) => s + d.remainingAmount, 0),
      groups: [
        { key: "hutang" as const, items: visible.filter((d) => d.type === "hutang") },
        { key: "piutang" as const, items: visible.filter((d) => d.type === "piutang") },
      ],
    }
  }, [data.debts, filter])

  const dateFmt = new Intl.DateTimeFormat(locale, { day: "numeric", month: "short", year: "numeric" })

  const dueLabel = (d: Debt) => {
    if (!d.dueDate) return <span>{t("debts.noDue")}</span>
    if (d.status !== "active") return <span>{dateFmt.format(d.dueDate)}</span>
    const days = Math.ceil((d.dueDate.getTime() - now.getTime()) / 86_400_000)
    if (days < 0) return <span style={{ color: "var(--expense)" }}>{t("debts.overdue", { days: -days })}</span>
    if (days <= 7) return <span style={{ color: "var(--warning)" }}>{t("debts.dueIn", { days })}</span>
    return <span>{dateFmt.format(d.dueDate)}</span>
  }

  if (!data.ready) {
    return (
      <div className="space-y-6">
        <Skeleton className="h-7 w-48" />
        <Skeleton className="h-24 w-full" />
        <Skeleton className="h-64 w-full" />
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title={t("debts.title")}
        description={t("debts.desc")}
        actions={
          <div className="seg" role="group" aria-label={t("debts.status")}>
            {(["active", "paid", "all"] as Filter[]).map((f) => (
              <button key={f} type="button" aria-pressed={filter === f} onClick={() => setFilter(f)}>{t(`debts.filter.${f}`)}</button>
            ))}
          </div>
        }
      />

      {failed ? (
        <Section><DataError /></Section>
      ) : (
        <>
          <div className="grid grid-cols-2 gap-px overflow-hidden rounded-lg border" style={{ borderColor: "var(--border)", backgroundColor: "var(--border)" }}>
            <Stat label={t("debts.owe")} value={owe} tone={owe > 0 ? "expense" : "neutral"} note={t("debts.oweNote")} />
            <Stat label={t("debts.owed")} value={owed} tone={owed > 0 ? "income" : "neutral"} note={t("debts.owedNote")} />
          </div>

          {groups.map(({ key, items }) => (
            <Section key={key} title={t(`debts.${key}`)} aside={t("debts.count", { count: items.length })} flush>
              {items.length === 0 ? (
                <EmptyState title={t("debts.empty")} />
              ) : (
                <ul>
                  {items.map((d) => {
                    const paid = d.amount - d.remainingAmount
                    return (
                      <li key={d.id} className="border-b px-5 py-4 last:border-b-0" style={{ borderColor: "var(--border)" }}>
                        <div className="flex items-start justify-between gap-4">
                          <div className="min-w-0">
                            <p className="flex items-center gap-2 text-sm font-medium" style={{ color: "var(--text-primary)" }}>
                              <span className="truncate">{d.personName || "—"}</span>
                              {d.status === "paid" && <Pill tone="income">{t("debts.paid")}</Pill>}
                              {d.status === "cancelled" && <Pill>{t("debts.cancelled")}</Pill>}
                            </p>
                            {d.description && <p className="mt-0.5 truncate text-xs" style={{ color: "var(--text-muted)" }}>{d.description}</p>}
                          </div>
                          <div className="shrink-0 text-right">
                            <Money value={d.remainingAmount} className="text-sm font-medium" />
                            <p className="text-xs" style={{ color: "var(--text-muted)" }}>{t("debts.of")} <Money value={d.amount} className="opacity-80" /></p>
                          </div>
                        </div>
                        <div className="mt-3"><ProgressBar value={paid} max={d.amount} kind="goal" label={d.personName || t(`debts.${d.type}`)} /></div>
                        <p className="mt-1.5 flex justify-between text-xs" style={{ color: "var(--text-muted)" }}>
                          {dueLabel(d)}
                          <span>{t("debts.paidAmount", { pct: d.amount > 0 ? Math.round((paid / d.amount) * 100) : 0 })}</span>
                        </p>
                      </li>
                    )
                  })}
                </ul>
              )}
            </Section>
          ))}
        </>
      )}
    </div>
  )
}

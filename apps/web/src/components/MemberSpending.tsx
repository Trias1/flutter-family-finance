"use client"

import { useMemo } from "react"
import { useTranslations } from "next-intl"

import DataError, { useFailed } from "@/components/DataError"
import { EmptyState, Money, Section } from "@/components/ui"
import { useFamilyData } from "@/lib/family-data"
import { byMember, spending } from "@/lib/finance"

/** Who spent what in one month (family mode only; savings transfers excluded). */
export default function MemberSpending({ from, to }: { from: Date; to: Date }) {
  const t = useTranslations("dash")
  const data = useFamilyData()
  const failed = useFailed("expenses", "members")

  const rows = useMemo(() => byMember(spending(data.expenses), from, to), [data.expenses, from, to])
  const total = rows.reduce((s, r) => s + r.amount, 0)

  if (data.scope !== "family") return null

  return (
    <Section title={t("members.title")} flush>
      {failed ? (
        <DataError />
      ) : rows.length === 0 ? (
        <EmptyState title={t("reports.noExpense")} />
      ) : (
        <ul>
          {rows.map((r) => {
            const share = total > 0 ? (r.amount / total) * 100 : 0
            // Records keep the author's uid after they leave the family.
            const name = data.memberName(r.userId) || t("members.former")
            return (
              <li key={r.userId || "unknown"} className="border-b px-5 py-3 last:border-b-0" style={{ borderColor: "var(--border)" }}>
                <div className="flex items-baseline justify-between gap-3 text-sm">
                  <span className="truncate" style={{ color: "var(--text-primary)" }}>{name}</span>
                  <Money value={r.amount} className="shrink-0" />
                </div>
                <div className="mt-1.5 flex items-center gap-3">
                  <div className="h-1.5 flex-1 overflow-hidden rounded-full" style={{ backgroundColor: "var(--surface-soft)" }} aria-hidden="true">
                    <div className="h-full rounded-full" style={{ width: `${share}%`, backgroundColor: "var(--primary)" }} />
                  </div>
                  <span className="w-20 text-right text-xs tabular-nums" style={{ color: "var(--text-muted)" }}>{t("members.share", { pct: share.toFixed(0) })}</span>
                </div>
              </li>
            )
          })}
        </ul>
      )}
    </Section>
  )
}

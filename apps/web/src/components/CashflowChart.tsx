"use client"

import { useLocale } from "next-intl"
import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts"

import { formatCompact, formatRupiah } from "@/lib/money"

export type CashflowPoint = { label: string; income: number; expense: number }

type TooltipProps = {
  active?: boolean
  label?: string
  payload?: { dataKey?: string | number; value?: number }[]
  labels: { income: string; expense: string; net: string }
}

function ChartTooltip({ active, label, payload, labels }: TooltipProps) {
  if (!active || !payload?.length) return null
  const income = Number(payload.find((p) => p.dataKey === "income")?.value ?? 0)
  const expense = Number(payload.find((p) => p.dataKey === "expense")?.value ?? 0)
  return (
    <div className="rounded-md border px-3 py-2 text-xs" style={{ backgroundColor: "var(--bg-card)", borderColor: "var(--border)", color: "var(--text-secondary)" }}>
      <p className="mb-1 font-medium" style={{ color: "var(--text-primary)" }}>{label}</p>
      <p className="flex justify-between gap-6"><span>{labels.income}</span><span className="tabular-nums" style={{ color: "var(--income)" }}>{formatRupiah(income)}</span></p>
      <p className="flex justify-between gap-6"><span>{labels.expense}</span><span className="tabular-nums" style={{ color: "var(--expense)" }}>{formatRupiah(expense)}</span></p>
      <p className="mt-1 flex justify-between gap-6 border-t pt-1" style={{ borderColor: "var(--border)" }}><span>{labels.net}</span><span className="tabular-nums" style={{ color: "var(--text-primary)" }}>{formatRupiah(income - expense)}</span></p>
    </div>
  )
}

export default function CashflowChart({ data, labels, height = 240, emptyLabel }: { data: CashflowPoint[]; labels: { income: string; expense: string; net: string }; height?: number; emptyLabel?: string }) {
  const locale = useLocale()
  if (emptyLabel && data.every((d) => d.income === 0 && d.expense === 0)) {
    return (
      <div style={{ height, borderColor: "var(--border)" }} className="flex items-center justify-center rounded-md border border-dashed text-sm" role="img" aria-label={emptyLabel}>
        <span style={{ color: "var(--text-muted)" }}>{emptyLabel}</span>
      </div>
    )
  }
  return (
    <div style={{ height }} className="w-full min-w-0">
      <ResponsiveContainer width="100%" height="100%" initialDimension={{ width: 320, height }}>
        <BarChart data={data} barGap={2} barCategoryGap="28%" margin={{ top: 4, right: 4, bottom: 0, left: 0 }}>
          <CartesianGrid vertical={false} stroke="var(--border)" />
          <XAxis dataKey="label" tickLine={false} axisLine={false} tick={{ fontSize: 12, fill: "var(--text-muted)" }} />
          <YAxis width={52} tickLine={false} axisLine={false} tick={{ fontSize: 11, fill: "var(--text-muted)" }} tickFormatter={(v: number) => formatCompact(v, locale)} />
          <Tooltip cursor={{ fill: "var(--surface-soft)" }} content={<ChartTooltip labels={labels} />} />
          <Bar dataKey="income" fill="var(--chart-in)" fillOpacity={0.9} isAnimationActive={false} radius={[3, 3, 0, 0]} maxBarSize={22} />
          <Bar dataKey="expense" fill="var(--chart-out)" fillOpacity={0.75} isAnimationActive={false} radius={[3, 3, 0, 0]} maxBarSize={22} />
        </BarChart>
      </ResponsiveContainer>
    </div>
  )
}

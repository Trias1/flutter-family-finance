"use client"

import { useId } from "react"
import { useLocale } from "next-intl"
import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts"

import { formatCompact, formatRupiah } from "@/lib/money"

/** `title` is the unabbreviated month (with year) for the accessible table. */
export type CashflowPoint = { label: string; title?: string; income: number; expense: number }

type Labels = { income: string; expense: string; net: string; month: string; caption: string }

type TooltipProps = {
  active?: boolean
  label?: string
  payload?: { dataKey?: string | number; value?: number }[]
  labels: Labels
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

/** Diagonal stripes, so spending bars differ from income bars by shape as well as colour. */
function Hatch({ id }: { id: string }) {
  return (
    <pattern id={id} width="6" height="6" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">
      <rect width="6" height="6" fill="var(--chart-out)" fillOpacity={0.35} />
      <rect width="3" height="6" fill="var(--chart-out)" fillOpacity={0.9} />
    </pattern>
  )
}

function Swatch({ hatchId }: { hatchId?: string }) {
  return (
    <svg width="10" height="10" aria-hidden="true" className="shrink-0">
      {hatchId && <defs><Hatch id={hatchId} /></defs>}
      <rect width="10" height="10" rx="2" fill={hatchId ? `url(#${hatchId})` : "var(--chart-in)"} />
    </svg>
  )
}

export default function CashflowChart({ data, labels, height = 240, emptyLabel }: { data: CashflowPoint[]; labels: Labels; height?: number; emptyLabel?: string }) {
  const locale = useLocale()
  // useId can contain characters that break url(#…) references.
  const uid = useId().replace(/[^a-zA-Z0-9_-]/g, "")
  const hatchId = `cf-hatch-${uid}`
  const swatchId = `cf-swatch-${uid}`

  if (emptyLabel && data.every((d) => d.income === 0 && d.expense === 0)) {
    return (
      <div style={{ height, borderColor: "var(--border)" }} className="flex items-center justify-center rounded-md border border-dashed text-sm" role="img" aria-label={emptyLabel}>
        <span style={{ color: "var(--text-muted)" }}>{emptyLabel}</span>
      </div>
    )
  }
  return (
    <figure>
      {/* The bars are decorative for screen readers; the table below carries the same numbers. */}
      <div style={{ height }} className="w-full min-w-0" aria-hidden="true">
        <ResponsiveContainer width="100%" height="100%" initialDimension={{ width: 320, height }}>
          <BarChart data={data} barGap={2} barCategoryGap="28%" margin={{ top: 4, right: 4, bottom: 0, left: 0 }} accessibilityLayer={false}>
            <defs><Hatch id={hatchId} /></defs>
            <CartesianGrid vertical={false} stroke="var(--border)" />
            <XAxis dataKey="label" tickLine={false} axisLine={false} tick={{ fontSize: 12, fill: "var(--text-muted)" }} />
            <YAxis width={52} tickLine={false} axisLine={false} tick={{ fontSize: 11, fill: "var(--text-muted)" }} tickFormatter={(v: number) => formatCompact(v, locale)} />
            <Tooltip cursor={{ fill: "var(--surface-soft)" }} content={<ChartTooltip labels={labels} />} />
            <Bar dataKey="income" fill="var(--chart-in)" fillOpacity={0.9} isAnimationActive={false} radius={[3, 3, 0, 0]} maxBarSize={22} />
            <Bar dataKey="expense" fill={`url(#${hatchId})`} stroke="var(--chart-out)" strokeWidth={1} isAnimationActive={false} radius={[3, 3, 0, 0]} maxBarSize={22} />
          </BarChart>
        </ResponsiveContainer>
      </div>
      <figcaption className="mt-3 flex gap-4 text-xs" style={{ color: "var(--text-muted)" }} aria-hidden="true">
        <span className="flex items-center gap-1.5"><Swatch />{labels.income}</span>
        <span className="flex items-center gap-1.5"><Swatch hatchId={swatchId} />{labels.expense}</span>
      </figcaption>
      <table className="sr-only">
        <caption>{labels.caption}</caption>
        <thead>
          <tr>
            <th scope="col">{labels.month}</th>
            <th scope="col">{labels.income}</th>
            <th scope="col">{labels.expense}</th>
            <th scope="col">{labels.net}</th>
          </tr>
        </thead>
        <tbody>
          {data.map((d, i) => (
            <tr key={`${d.label}-${i}`}>
              <th scope="row">{d.title ?? d.label}</th>
              <td>{formatRupiah(d.income)}</td>
              <td>{formatRupiah(d.expense)}</td>
              <td>{formatRupiah(d.income - d.expense)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </figure>
  )
}

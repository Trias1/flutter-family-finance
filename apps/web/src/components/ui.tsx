import type { ReactNode } from "react"

import { formatRupiah } from "@/lib/money"

export function PageHeader({ title, description, actions }: { title: string; description?: string; actions?: ReactNode }) {
  return (
    <div className="mb-6 flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
      <div>
        <h1 className="text-xl font-semibold tracking-tight" style={{ color: "var(--text-primary)" }}>{title}</h1>
        {description && <p className="mt-1 text-sm" style={{ color: "var(--text-secondary)" }}>{description}</p>}
      </div>
      {actions}
    </div>
  )
}

export function Section({ title, aside, children, flush = false }: { title?: string; aside?: ReactNode; children: ReactNode; flush?: boolean }) {
  return (
    <section className="rounded-lg border" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
      {title && (
        <header className="flex items-center justify-between gap-3 border-b px-5 py-3.5" style={{ borderColor: "var(--border)" }}>
          <h2 className="text-sm font-semibold" style={{ color: "var(--text-primary)" }}>{title}</h2>
          {aside && <div className="text-xs" style={{ color: "var(--text-muted)" }}>{aside}</div>}
        </header>
      )}
      <div className={flush ? "" : "p-5"}>{children}</div>
    </section>
  )
}

export function Money({ value, tone = "neutral", signed = false, className = "" }: { value: number; tone?: "neutral" | "income" | "expense" | "auto"; signed?: boolean; className?: string }) {
  const resolved = tone === "auto" ? (value < 0 ? "expense" : "neutral") : tone
  const color = resolved === "income" ? "var(--income)" : resolved === "expense" ? "var(--expense)" : "var(--text-primary)"
  const prefix = signed && value > 0 ? "+" : ""
  return (
    <span className={`tabular-nums ${className}`} style={{ color }}>
      {prefix}{formatRupiah(value)}
    </span>
  )
}

/** One cell of the summary strip: label, big figure, quiet footnote. */
export function Stat({ label, value, tone = "neutral", note }: { label: string; value: number; tone?: "neutral" | "income" | "expense" | "auto"; note?: ReactNode }) {
  return (
    <div className="px-5 py-4" style={{ backgroundColor: "var(--bg-card)" }}>
      <p className="text-xs font-medium uppercase tracking-[0.08em]" style={{ color: "var(--text-muted)" }}>{label}</p>
      <p className="mt-2 text-xl font-semibold sm:text-2xl"><Money value={value} tone={tone} /></p>
      {note && <p className="mt-1 text-xs" style={{ color: "var(--text-muted)" }}>{note}</p>}
    </div>
  )
}

export function StatStrip({ children }: { children: ReactNode }) {
  return (
    // The 1px gaps show the container colour through, drawing the rules between cells.
    <div className="grid grid-cols-2 gap-px overflow-hidden rounded-lg border lg:grid-cols-4" style={{ borderColor: "var(--border)", backgroundColor: "var(--border)" }}>
      {children}
    </div>
  )
}

/**
 * `limit` bars (budgets) turn amber near the limit and red past it;
 * `goal` bars (savings, repayments) turn green when complete.
 */
export function ProgressBar({ value, max, kind = "limit", warnAt = 0.85 }: { value: number; max: number; kind?: "limit" | "goal"; warnAt?: number }) {
  const ratio = max > 0 ? value / max : 0
  const color =
    kind === "goal"
      ? ratio >= 1 ? "var(--income)" : "var(--primary)"
      : ratio >= 1 ? "var(--expense)" : ratio >= warnAt ? "var(--warning)" : "var(--primary)"
  return (
    <div className="h-1.5 w-full overflow-hidden rounded-full" style={{ backgroundColor: "var(--surface-soft)" }} role="progressbar" aria-valuenow={Math.round(ratio * 100)} aria-valuemin={0} aria-valuemax={100}>
      <div className="h-full rounded-full" style={{ width: `${Math.min(ratio, 1) * 100}%`, backgroundColor: color }} />
    </div>
  )
}

export function EmptyState({ title, hint }: { title: string; hint?: string }) {
  return (
    <div className="px-5 py-10 text-center">
      <p className="text-sm font-medium" style={{ color: "var(--text-secondary)" }}>{title}</p>
      {hint && <p className="mx-auto mt-1 max-w-sm text-xs leading-5" style={{ color: "var(--text-muted)" }}>{hint}</p>}
    </div>
  )
}

export function Skeleton({ className = "" }: { className?: string }) {
  return <div className={`animate-pulse rounded ${className}`} style={{ backgroundColor: "var(--surface-soft)" }} />
}

export function Pill({ children, tone = "neutral" }: { children: ReactNode; tone?: "neutral" | "income" | "expense" | "warning" }) {
  const color = tone === "income" ? "var(--income)" : tone === "expense" ? "var(--expense)" : tone === "warning" ? "var(--warning)" : "var(--text-secondary)"
  return (
    <span className="inline-flex items-center rounded border px-1.5 py-0.5 text-[11px] font-medium" style={{ color, borderColor: "color-mix(in srgb, currentColor 30%, transparent)" }}>
      {children}
    </span>
  )
}

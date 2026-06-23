export function SkeletonCard({ className = "" }: { className?: string }) {
  return (
    <div className={`rounded-2xl border p-5 animate-pulse ${className}`} style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
      <div className="h-3 w-20 rounded bg-skeleton mb-3" />
      <div className="h-7 w-32 rounded bg-skeleton mb-2" />
      <div className="h-3 w-24 rounded bg-skeleton-soft" />
    </div>
  )
}

export function SkeletonLine({ width = "100%", height = 14, className = "" }: { width?: string; height?: number | string; className?: string }) {
  return <div className={`rounded animate-pulse ${className}`} style={{ width, height, backgroundColor: "var(--border)" }} />
}

export function SkeletonAvatar({ size = 40 }: { size?: number }) {
  return <div className="rounded-xl animate-pulse" style={{ width: size, height: size, backgroundColor: "var(--border)" }} />
}

export function SkeletonBar({ pct = 60 }: { pct?: number }) {
  return (
    <div className="space-y-2 animate-pulse">
      <div className="flex justify-between">
        <div className="h-3 w-16 rounded bg-skeleton" />
        <div className="h-3 w-24 rounded bg-skeleton" />
      </div>
      <div className="h-2.5 w-full rounded-full bg-skeleton-soft">
        <div className="h-full rounded-full bg-skeleton" style={{ width: `${pct}%` }} />
      </div>
    </div>
  )
}

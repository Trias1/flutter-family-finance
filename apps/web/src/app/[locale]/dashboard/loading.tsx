import DashboardShell from "@/components/DashboardShell"

export default function DashboardLoading() {
  return (
    <DashboardShell>
      <div className="space-y-6 animate-pulse max-w-3xl mx-auto">
        <div className="h-8 w-40 rounded bg-skeleton" />
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-5">
          {[...Array(4)].map((_, i) => (
            <div key={i} className="rounded-2xl border p-6" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
              <div className="h-3 w-20 rounded bg-skeleton mb-3" />
              <div className="h-7 w-32 rounded bg-skeleton mb-2" />
              <div className="h-3 w-24 rounded bg-skeleton-soft" />
            </div>
          ))}
        </div>
      </div>
    </DashboardShell>
  )
}

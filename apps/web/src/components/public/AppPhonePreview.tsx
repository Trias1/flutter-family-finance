// Static sample of the dashboard's monthly summary, used on public pages.
// Figures are illustrative; the labels say so.

const rows: { label: string; category: string; amount: number }[] = [
  { label: "Gaji", category: "Pemasukan", amount: 9_500_000 },
  { label: "Belanja bulanan", category: "Kebutuhan rumah", amount: -1_240_000 },
  { label: "Listrik PLN", category: "Tagihan", amount: -386_500 },
  { label: "SPP sekolah", category: "Pendidikan", amount: -750_000 },
  { label: "Tabungan emas", category: "Tabungan", amount: -1_000_000 },
]

const budgets: { label: string; used: number; limit: number }[] = [
  { label: "Kebutuhan rumah", used: 2_870_000, limit: 3_500_000 },
  { label: "Transportasi", used: 610_000, limit: 800_000 },
  { label: "Makan di luar", used: 455_000, limit: 500_000 },
]

const rupiah = (value: number) =>
  `${value < 0 ? "−" : ""}Rp${Math.abs(value).toLocaleString("id-ID")}`

export default function AppPhonePreview({ className = "" }: { className?: string }) {
  return (
    <figure className={`overflow-hidden rounded-lg border text-left ${className}`} style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
      <div className="flex items-baseline justify-between border-b px-4 py-3" style={{ borderColor: "var(--border)" }}>
        <span className="text-xs font-semibold uppercase tracking-[0.12em]" style={{ color: "var(--text-muted)" }}>Oktober</span>
        <span className="text-xs" style={{ color: "var(--text-muted)" }}>contoh data</span>
      </div>

      <dl className="grid grid-cols-2 border-b" style={{ borderColor: "var(--border)" }}>
        <div className="border-r px-4 py-3" style={{ borderColor: "var(--border)" }}>
          <dt className="text-xs" style={{ color: "var(--text-muted)" }}>Pemasukan</dt>
          <dd className="mt-1 font-mono text-sm font-semibold tabular-nums" style={{ color: "var(--income)" }}>Rp9.500.000</dd>
        </div>
        <div className="px-4 py-3">
          <dt className="text-xs" style={{ color: "var(--text-muted)" }}>Pengeluaran</dt>
          <dd className="mt-1 font-mono text-sm font-semibold tabular-nums" style={{ color: "var(--expense)" }}>Rp3.376.500</dd>
        </div>
      </dl>

      <ul>
        {rows.map((row) => (
          <li key={row.label} className="flex items-center justify-between border-b px-4 py-2.5" style={{ borderColor: "var(--border)" }}>
            <div>
              <p className="text-sm" style={{ color: "var(--text-primary)" }}>{row.label}</p>
              <p className="text-xs" style={{ color: "var(--text-muted)" }}>{row.category}</p>
            </div>
            <span className="font-mono text-sm tabular-nums" style={{ color: row.amount > 0 ? "var(--income)" : "var(--text-primary)" }}>
              {rupiah(row.amount)}
            </span>
          </li>
        ))}
      </ul>

      <div className="space-y-3 px-4 py-4">
        {budgets.map((budget) => {
          const pct = Math.round((budget.used / budget.limit) * 100)
          return (
            <div key={budget.label}>
              <div className="flex justify-between text-xs">
                <span style={{ color: "var(--text-secondary)" }}>{budget.label}</span>
                <span className="font-mono tabular-nums" style={{ color: pct >= 90 ? "var(--expense)" : "var(--text-muted)" }}>{pct}%</span>
              </div>
              <div className="mt-1.5 h-1 rounded-full" style={{ backgroundColor: "var(--surface-soft)" }}>
                <div className="h-1 rounded-full" style={{ width: `${pct}%`, backgroundColor: pct >= 90 ? "var(--expense)" : "var(--primary)" }} />
              </div>
            </div>
          )
        })}
      </div>
    </figure>
  )
}

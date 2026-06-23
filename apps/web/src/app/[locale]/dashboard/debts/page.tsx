"use client"

import { useEffect, useState } from "react"
import { collection, query, where, getDocs, getDoc, doc, Timestamp } from "firebase/firestore"
import { onAuthStateChanged } from "firebase/auth"
import { auth, db } from "@/lib/firebase"
import { useTranslations } from "next-intl"
import DashboardShell from "@/components/DashboardShell"
import { SkeletonCard, SkeletonLine, SkeletonAvatar } from "@/components/Skeleton"

interface Debt { id: string; personName: string; type: "debt" | "receivable"; amount: number; remainingAmount: number; description: string; dueDate: Date | null; status: string }

export default function DebtsPage() {
  const t = useTranslations()
  const [debts, setDebts] = useState<Debt[]>([])
  const [filter, setFilter] = useState<"all" | "debt" | "receivable">("all")
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (u) => {
      try {
        if (!u) return
        const snap = await getDoc(doc(db, "users", u.uid))
        const fid = snap.data()?.familyId
        if (!fid) return
        const debtSnap = await getDocs(query(collection(db, "debts"), where("familyId", "==", fid)))
        setDebts(debtSnap.docs.map((d) => {
          const data = d.data()
          return { id: d.id, personName: data.personName || "", type: data.type || "debt", amount: data.amount || 0, remainingAmount: data.remainingAmount ?? data.amount ?? 0, description: data.description || "", dueDate: (data.dueDate as Timestamp)?.toDate?.() || null, status: data.status || "active" } as Debt
        }))
      } finally {
        setLoading(false)
      }
    })
    return unsub
  }, [])

  const fmt = (n: number) => "Rp" + Math.floor(n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".")
  const filtered = debts.filter((d) => filter === "all" || d.type === filter)
  const totalDebt = debts.filter((d) => d.type === "debt").reduce((s, d) => s + d.remainingAmount, 0)
  const totalReceivable = debts.filter((d) => d.type === "receivable").reduce((s, d) => s + d.remainingAmount, 0)
  const statusColors: Record<string, string> = { active: "#FFA726", paid: "#4CAF50", overdue: "#EF5350" }
  const statusLabels: Record<string, string> = { active: "Aktif", paid: "Lunas", overdue: "Terlambat" }

  if (loading) {
    return (
      <DashboardShell>
        <div className="max-w-3xl mx-auto space-y-6">
          <SkeletonLine width="180px" height={28} />
          <div className="grid grid-cols-2 gap-4">
            <SkeletonCard />
            <SkeletonCard />
          </div>
          <div className="flex gap-2">
            <SkeletonLine width="80px" height={36} className="rounded-xl" />
            <SkeletonLine width="80px" height={36} className="rounded-xl" />
            <SkeletonLine width="80px" height={36} className="rounded-xl" />
          </div>
          <div className="space-y-3">
            {[1,2,3].map((i) => (
              <div key={i} className="rounded-2xl border p-5 animate-pulse" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
                <div className="flex items-center gap-4">
                  <SkeletonAvatar size={48} />
                  <div className="flex-1 space-y-2">
                    <SkeletonLine width="40%" height={16} />
                    <SkeletonLine width="60%" height={12} />
                  </div>
                    <SkeletonLine width="80px" height={18} />
                </div>
              </div>
            ))}
          </div>
        </div>
      </DashboardShell>
    )
  }

  return (
    <DashboardShell>
      <div className="max-w-3xl mx-auto space-y-6">
        <h1 className="text-2xl font-bold" style={{ color: "var(--text-primary)" }}>{t("nav.debts")}</h1>

        <div className="grid grid-cols-2 gap-4">
          <div className="rounded-2xl border p-5" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
            <p className="text-sm" style={{ color: "var(--text-secondary)" }}>Total Hutang</p>
            <p className="text-2xl font-bold mt-1" style={{ color: "#EF5350" }}>{fmt(totalDebt)}</p>
          </div>
          <div className="rounded-2xl border p-5" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
            <p className="text-sm" style={{ color: "var(--text-secondary)" }}>Total Piutang</p>
            <p className="text-2xl font-bold mt-1" style={{ color: "#4CAF50" }}>{fmt(totalReceivable)}</p>
          </div>
        </div>

        <div className="flex gap-2">
          {(["all", "debt", "receivable"] as const).map((f) => (
            <button key={f} onClick={() => setFilter(f)}
              className="rounded-xl px-4 py-2 text-sm font-medium transition-all"
              style={{ backgroundColor: filter === f ? "var(--primary)" : "var(--bg-card)", color: filter === f ? "#FFFFFF" : "var(--text-secondary)", border: filter === f ? "none" : "1px solid var(--border)" }}
            >{f === "all" ? "Semua" : f === "debt" ? "Hutang" : "Piutang"}</button>
          ))}
        </div>

        <div className="space-y-3">
          {filtered.length === 0 ? (
            <p className="text-center text-sm py-12" style={{ color: "var(--text-muted)" }}>Belum ada data</p>
          ) : filtered.map((d) => (
            <div key={d.id} className="rounded-2xl border p-5" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
              <div className="flex items-center gap-4">
                <div className="flex h-12 w-12 items-center justify-center rounded-xl text-xl" style={{ backgroundColor: d.type === "debt" ? "var(--expense-bg)" : "var(--primary-bg)" }}>{d.type === "debt" ? "📤" : "📥"}</div>
                <div className="flex-1 min-w-0">
                  <p className="font-semibold" style={{ color: "var(--text-primary)" }}>{d.personName}</p>
                  <p className="text-sm truncate" style={{ color: "var(--text-muted)" }}>{d.description || (d.type === "debt" ? "Hutang" : "Piutang")}</p>
                  {d.dueDate && <p className="text-xs mt-1" style={{ color: "var(--text-muted)" }}>Jatuh tempo: {d.dueDate.toLocaleDateString("id-ID")}</p>}
                </div>
                <div className="text-right">
                  <p className="font-bold" style={{ color: "var(--text-primary)" }}>{fmt(d.remainingAmount)}</p>
                  <span className="inline-block mt-1 rounded-full px-2 py-0.5 text-[10px] font-medium text-white" style={{ backgroundColor: statusColors[d.status] || "var(--text-muted)" }}>{statusLabels[d.status] || d.status}</span>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </DashboardShell>
  )
}

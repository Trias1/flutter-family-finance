"use client"

import { useEffect, useState } from "react"
import { collection, query, where, getDocs, getDoc, doc, Timestamp } from "firebase/firestore"
import { onAuthStateChanged } from "firebase/auth"
import { auth, db } from "@/lib/firebase"
import { useTranslations } from "next-intl"
import DashboardShell from "@/components/DashboardShell"
import { SkeletonLine } from "@/components/Skeleton"

interface Tx { id: string; amount: number; category: string; date: Date; note: string; type: "income" | "expense" }

export default function TransactionsPage() {
  const t = useTranslations()
  const [txs, setTxs] = useState<Tx[]>([])
  const [loading, setLoading] = useState(true)
  const [filterType, setFilterType] = useState<"all" | "income" | "expense">("all")
  const [search, setSearch] = useState("")

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (u) => {
      try {
        if (!u) return
        const snap = await getDoc(doc(db, "users", u.uid))
        const fid = snap.data()?.familyId
        if (!fid) return
        const [incSnap, expSnap] = await Promise.all([
          getDocs(query(collection(db, "incomes"), where("familyId", "==", fid))),
          getDocs(query(collection(db, "expenses"), where("familyId", "==", fid))),
        ])
        const parseDoc = (d: any, type: "income" | "expense"): Tx => ({ id: d.id, amount: (d.data().amount as number) || 0, category: d.data().category || "", date: ((d.data().date as Timestamp)?.toDate()) || new Date(), note: d.data().note || "", type })
        const all: Tx[] = [...incSnap.docs.map((d) => parseDoc(d, "income")), ...expSnap.docs.map((d) => parseDoc(d, "expense"))]
        all.sort((a, b) => b.date.getTime() - a.date.getTime())
        setTxs(all)
      } finally {
        setLoading(false)
      }
    })
    return unsub
  }, [])

  const fmt = (n: number) => "Rp" + Math.floor(n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".")

  if (loading) {
    return (
      <DashboardShell>
        <div className="max-w-3xl mx-auto space-y-4 animate-pulse">
          <div className="h-7 w-40 rounded bg-skeleton" />
          <div className="flex flex-col sm:flex-row gap-3">
            <div className="flex-1 h-11 rounded-xl bg-skeleton-soft" />
            <div className="flex gap-2">
              {[...Array(3)].map((_, i) => <div key={i} className="h-11 w-20 rounded-xl bg-skeleton-soft" />)}
            </div>
          </div>
          <div className="space-y-2">
            {[...Array(5)].map((_, i) => (
              <div key={i} className="rounded-xl border px-5 py-3.5" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
                <div className="flex items-center gap-3">
                  <div className="h-9 w-9 rounded-xl bg-skeleton-soft" />
                  <div className="flex-1 space-y-1.5">
                    <div className="h-3.5 w-28 rounded bg-skeleton" />
                    <div className="h-3 w-20 rounded bg-skeleton-soft" />
                  </div>
                  <div className="h-4 w-24 rounded bg-skeleton" />
                </div>
              </div>
            ))}
          </div>
        </div>
      </DashboardShell>
    )
  }

  const filtered = txs.filter((tx) => {
    if (filterType !== "all" && tx.type !== filterType) return false
    if (search && !tx.category.toLowerCase().includes(search.toLowerCase()) && !tx.note.toLowerCase().includes(search.toLowerCase())) return false
    return true
  })

  return (
    <DashboardShell>
      <div className="max-w-3xl mx-auto space-y-4">
        <h1 className="text-2xl font-bold" style={{ color: "var(--text-primary)" }}>{t("nav.transactions")}</h1>

        <div className="flex flex-col sm:flex-row gap-3">
          <input type="text" placeholder="Cari kategori atau catatan..." value={search} onChange={(e) => setSearch(e.target.value)}
            className="flex-1 rounded-xl border px-4 py-2.5 text-sm outline-none" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)", color: "var(--text-primary)" }} />
          <div className="flex gap-2">
            {(["all", "income", "expense"] as const).map((f) => (
              <button key={f} onClick={() => setFilterType(f)}
                className="rounded-xl px-4 py-2.5 text-sm font-medium transition-all"
                style={{ backgroundColor: filterType === f ? "var(--primary)" : "var(--bg-card)", color: filterType === f ? "#FFFFFF" : "var(--text-secondary)", border: filterType === f ? "none" : "1px solid var(--border)" }}
              >{f === "all" ? "Semua" : f === "income" ? "Pemasukan" : "Pengeluaran"}</button>
            ))}
          </div>
        </div>

        <div className="space-y-2">
          {filtered.length === 0 ? (
            <p className="text-center text-sm py-12" style={{ color: "var(--text-muted)" }}>Tidak ada transaksi</p>
          ) : filtered.map((tx) => (
            <div key={tx.id} className="rounded-xl border px-5 py-3.5" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
              <div className="flex items-center gap-3">
                <div className="flex h-9 w-9 items-center justify-center rounded-xl text-sm" style={{ backgroundColor: tx.type === "income" ? "var(--primary-bg)" : "var(--expense-bg)" }}>{tx.type === "income" ? "📥" : "📤"}</div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium" style={{ color: "var(--text-primary)" }}>{tx.category}</p>
                  <p className="text-xs" style={{ color: "var(--text-muted)" }}>{tx.note || tx.date.toLocaleDateString("id-ID")}</p>
                </div>
                <span className={`text-sm font-semibold ${tx.type === "income" ? "text-income" : "text-expense"}`}>{tx.type === "income" ? "+" : "-"}{fmt(tx.amount)}</span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </DashboardShell>
  )
}

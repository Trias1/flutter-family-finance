"use client"

import { useEffect, useState } from "react"
import { collection, query, where, getDocs, getDoc, doc } from "firebase/firestore"
import { onAuthStateChanged } from "firebase/auth"
import { auth, db } from "@/lib/firebase"
import { useTranslations } from "next-intl"
import DashboardShell from "@/components/DashboardShell"
import { SkeletonLine, SkeletonAvatar } from "@/components/Skeleton"

interface Wallet { id: string; name: string; balance: number; type: string }

const typeIcons: Record<string, string> = { cash: "💵", bank: "🏦", ewallet: "📱" }

export default function WalletsPage() {
  const t = useTranslations()
  const [wallets, setWallets] = useState<Wallet[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (u) => {
      try {
        if (!u) return
        const snap = await getDoc(doc(db, "users", u.uid))
        const fid = snap.data()?.familyId
        if (!fid) return
        const walletSnap = await getDocs(query(collection(db, "wallets"), where("familyId", "==", fid)))
        setWallets(walletSnap.docs.map((d) => ({ id: d.id, ...d.data() } as Wallet)))
      } finally {
        setLoading(false)
      }
    })
    return unsub
  }, [])

  const fmt = (n: number) => "Rp" + Math.floor(n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".")
  const total = wallets.reduce((s, w) => s + w.balance, 0)

  if (loading) {
    return (
      <DashboardShell>
        <div className="max-w-3xl mx-auto space-y-6">
          <div className="h-7 w-40 rounded bg-skeleton" />
          <div className="rounded-2xl border p-6 animate-pulse" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
            <div className="h-3.5 w-28 rounded bg-skeleton mb-3" />
            <div className="h-8 w-48 rounded bg-skeleton mb-2" />
            <div className="h-3 w-32 rounded bg-skeleton-soft" />
          </div>
          {[1, 2, 3].map((i) => (
            <div key={i} className="rounded-2xl border p-5" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
              <div className="flex items-center gap-4">
                <SkeletonAvatar />
                <div className="flex-1 space-y-2">
                  <SkeletonLine width="140px" height="16px" />
                  <SkeletonLine width="80px" height="12px" />
                </div>
                <SkeletonLine width="120px" height="20px" />
              </div>
            </div>
          ))}
        </div>
      </DashboardShell>
    )
  }

  return (
    <DashboardShell>
      <div className="max-w-3xl mx-auto space-y-6">
        <h1 className="text-2xl font-bold" style={{ color: "var(--text-primary)" }}>{t("nav.wallets")}</h1>

        <div className="rounded-2xl border p-6" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
          <p className="text-sm font-medium" style={{ color: "var(--text-secondary)" }}>{t("dashboard.totalBalance")}</p>
          <p className="text-3xl font-bold mt-1" style={{ color: "var(--text-primary)" }}>{fmt(total)}</p>
        </div>

        <div className="grid gap-4">
          {wallets.length === 0 ? (
            <p className="text-center text-sm py-12" style={{ color: "var(--text-muted)" }}>Belum ada dompet</p>
          ) : (
            wallets.map((w) => (
              <div key={w.id} className="rounded-2xl border p-5 hover:shadow-md transition-all" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
                <div className="flex items-center gap-4">
                  <div className="flex h-12 w-12 items-center justify-center rounded-xl text-xl" style={{ backgroundColor: "var(--primary-bg)" }}>{typeIcons[w.type] || "👛"}</div>
                  <div className="flex-1 min-w-0">
                    <p className="font-semibold" style={{ color: "var(--text-primary)" }}>{w.name}</p>
                    <p className="text-sm capitalize" style={{ color: "var(--text-muted)" }}>{w.type}</p>
                  </div>
                  <p className="text-lg font-bold" style={{ color: "var(--text-primary)" }}>{fmt(w.balance)}</p>
                </div>
              </div>
            ))
          )}
        </div>
      </div>
    </DashboardShell>
  )
}

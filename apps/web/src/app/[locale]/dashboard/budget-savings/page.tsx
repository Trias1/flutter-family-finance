"use client"

import { useEffect, useState } from "react"
import { collection, query, where, getDocs, getDoc, doc } from "firebase/firestore"
import { onAuthStateChanged } from "firebase/auth"
import { auth, db } from "@/lib/firebase"
import { useTranslations } from "next-intl"
import DashboardShell from "@/components/DashboardShell"
import { SkeletonCard, SkeletonLine, SkeletonBar } from "@/components/Skeleton"

function fmt(n: number) {
  return "Rp" + Math.floor(n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".")
}

const EXPENSE = "#EF5350"
const GREEN = "#6B3F2A"
const GREEN_LIGHT = "#D97706"

export default function BudgetSavingsPage() {
  const t = useTranslations()
  const [budgets, setBudgets] = useState<any[]>([])
  const [savings, setSavings] = useState<any[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (u) => {
      try {
        if (!u) return
        const snap = await getDoc(doc(db, "users", u.uid))
        const fid = snap.data()?.familyId
        if (!fid) return
        const [budgetSnap, savingSnap] = await Promise.all([
          getDocs(query(collection(db, "budgets"), where("familyId", "==", fid))),
          getDocs(query(collection(db, "savings"), where("familyId", "==", fid))),
        ])
        setBudgets(budgetSnap.docs.map((d) => ({ id: d.id, ...d.data() })))
        setSavings(savingSnap.docs.map((d) => ({ id: d.id, ...d.data() })))
      } finally {
        setLoading(false)
      }
    })
    return unsub
  }, [])

  const totalBudget = budgets.reduce((s, b) => s + (b.amount || 0), 0)
  const totalUsed = budgets.reduce((s, b) => s + (b.usedAmount || 0), 0)
  const totalSavingTarget = savings.reduce((s, sv) => s + (sv.targetAmount || 0), 0)
  const totalSavingCurrent = savings.reduce((s, sv) => s + (sv.currentAmount || 0), 0)

  if (loading) {
    return (
      <DashboardShell>
        <div className="max-w-3xl mx-auto space-y-6">
          <SkeletonLine width="200px" height={28} />
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <SkeletonCard />
            <SkeletonCard />
          </div>
          <div className="rounded-2xl border p-6 animate-pulse" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
            <SkeletonLine width="120px" height={20} />
            <div className="mt-4 space-y-5">
              {[1,2,3].map((i) => <SkeletonBar key={i} pct={[40, 70, 30][i-1]} />)}
            </div>
          </div>
          <div className="rounded-2xl border p-6 animate-pulse" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
            <SkeletonLine width="120px" height={20} />
            <div className="mt-4 space-y-5">
              {[1,2,3].map((i) => <SkeletonBar key={i} pct={[50, 80, 20][i-1]} />)}
            </div>
          </div>
        </div>
      </DashboardShell>
    )
  }

  return (
    <DashboardShell>
      <div className="max-w-3xl mx-auto space-y-6">
        <h1 className="text-2xl font-bold" style={{ color: "var(--text-primary)" }}>{t("nav.budgetSavings")}</h1>

        {/* Info card */}
        <div className="rounded-2xl border p-4 text-sm leading-relaxed" style={{ borderColor: "var(--border)", backgroundColor: "var(--primary-bg)", color: "var(--primary)" }}>
          <p>{t("budgetSavings.desc")}</p>
          <p className="mt-2 text-xs opacity-80">📱 {t("budgetSavings.note")}</p>
        </div>

        {/* Summary Cards */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div className="rounded-2xl border p-5" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
            <p className="text-sm" style={{ color: "var(--text-secondary)" }}>{t("dashboard.budget")}</p>
            <p className="text-xl font-bold mt-1" style={{ color: "var(--text-primary)" }}>{fmt(totalUsed)} / {fmt(totalBudget)}</p>
            <div className="mt-3 h-2.5 w-full rounded-full" style={{ backgroundColor: "var(--surface-soft)" }}>
              <div className="h-full rounded-full transition-all duration-300" style={{ width: `${totalBudget > 0 ? Math.min((totalUsed / totalBudget) * 100, 100) : 0}%`, backgroundColor: totalBudget > 0 && totalUsed >= totalBudget ? EXPENSE : GREEN_LIGHT }} />
            </div>
          </div>
          <div className="rounded-2xl border p-5" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
            <p className="text-sm" style={{ color: "var(--text-secondary)" }}>{t("dashboard.savings")}</p>
            <p className="text-xl font-bold mt-1" style={{ color: "var(--text-primary)" }}>{fmt(totalSavingCurrent)} / {fmt(totalSavingTarget)}</p>
            <div className="mt-3 h-2.5 w-full rounded-full" style={{ backgroundColor: "var(--surface-soft)" }}>
              <div className="h-full rounded-full transition-all duration-300" style={{ width: `${totalSavingTarget > 0 ? Math.min((totalSavingCurrent / totalSavingTarget) * 100, 100) : 0}%`, backgroundColor: GREEN }} />
            </div>
          </div>
        </div>

        {/* Budget List */}
        <div className="rounded-2xl border p-6" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
          <h3 className="text-lg font-semibold" style={{ color: "var(--text-primary)" }}>{t("dashboard.budget")}</h3>
          {budgets.length === 0 ? (
            <p className="mt-4 text-sm" style={{ color: "var(--text-muted)" }}>{t("dashboard.noBudget")}</p>
          ) : (
            <div className="mt-4 space-y-5">
              {budgets.map((b: any) => {
                const pct = b.amount > 0 ? Math.min((b.usedAmount / b.amount) * 100, 100) : 0
                return (
                  <div key={b.id}>
                    <div className="flex justify-between text-sm mb-1">
                      <span className="font-medium" style={{ color: "var(--text-primary)" }}>{b.category}</span>
                      <span style={{ color: "var(--text-secondary)" }}>{fmt(b.usedAmount)} / {fmt(b.amount)}</span>
                    </div>
                    <div className="flex items-center gap-3">
                      <div className="flex-1 h-2.5 rounded-full" style={{ backgroundColor: "var(--surface-soft)" }}>
                        <div className="h-full rounded-full transition-all duration-300" style={{ width: `${pct}%`, backgroundColor: pct >= 100 ? EXPENSE : GREEN_LIGHT }} />
                      </div>
                      <span className="text-xs font-medium w-10 text-right" style={{ color: pct >= 100 ? EXPENSE : "var(--text-secondary)" }}>{pct.toFixed(0)}%</span>
                    </div>
                  </div>
                )
              })}
            </div>
          )}
        </div>

        {/* Savings List */}
        <div className="rounded-2xl border p-6" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
          <h3 className="text-lg font-semibold" style={{ color: "var(--text-primary)" }}>{t("dashboard.savings")}</h3>
          {savings.length === 0 ? (
            <p className="mt-4 text-sm" style={{ color: "var(--text-muted)" }}>{t("dashboard.noSavings")}</p>
          ) : (
            <div className="mt-4 space-y-5">
              {savings.map((s: any) => {
                const pct = s.targetAmount > 0 ? Math.min((s.currentAmount / s.targetAmount) * 100, 100) : 0
                return (
                  <div key={s.id}>
                    <div className="flex justify-between text-sm mb-1">
                      <div>
                        <span className="font-medium" style={{ color: "var(--text-primary)" }}>{s.name}</span>
                        {s.category && <span className="ml-2 text-xs" style={{ color: "var(--text-muted)" }}>({s.category})</span>}
                      </div>
                      <span style={{ color: "var(--text-secondary)" }}>{fmt(s.currentAmount)} / {fmt(s.targetAmount)}</span>
                    </div>
                    <div className="flex items-center gap-3">
                      <div className="flex-1 h-2.5 rounded-full" style={{ backgroundColor: "var(--surface-soft)" }}>
                        <div className="h-full rounded-full transition-all duration-300" style={{ width: `${pct}%`, backgroundColor: GREEN }} />
                      </div>
                      <span className="text-xs font-medium w-10 text-right" style={{ color: "var(--text-secondary)" }}>{pct.toFixed(0)}%</span>
                    </div>
                  </div>
                )
              })}
            </div>
          )}
        </div>
      </div>
    </DashboardShell>
  )
}

"use client"

import { useEffect, useState } from "react"
import { collection, query, where, getDocs, getDoc, doc, Timestamp } from "firebase/firestore"
import { onAuthStateChanged } from "firebase/auth"
import { auth, db } from "@/lib/firebase"
import { useTranslations } from "next-intl"
import DashboardShell from "@/components/DashboardShell"
import { SkeletonCard, SkeletonLine } from "@/components/Skeleton"
import {
  BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid, PieChart, Pie, Cell,
} from "recharts"

const COLORS = ["#6B3F2A", "#A16207", "#D97706", "#F59E0B", "#F3E7D8", "#EF5350", "#42A5F5", "#AB47BC", "#26A69A", "#8B5CF6"]
const INCOME = "#4CAF50"
const EXPENSE = "#EF5350"

function fmt(n: number) {
  return "Rp" + Math.floor(n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".")
}

type Period = "daily" | "weekly" | "monthly" | "yearly"

export default function ReportsPage() {
  const t = useTranslations()
  const [incomes, setIncomes] = useState<any[]>([])
  const [expenses, setExpenses] = useState<any[]>([])
  const [period, setPeriod] = useState<Period>("monthly")
  const [loading, setLoading] = useState(true)

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
        const parse = (d: any) => ({ id: d.id, amount: (d.data().amount as number) || 0, category: d.data().category || "", date: (d.data().date as Timestamp)?.toDate?.() || new Date(), note: d.data().note || "" })
        setIncomes(incSnap.docs.map(parse))
        setExpenses(expSnap.docs.map(parse))
      } finally {
        setLoading(false)
      }
    })
    return unsub
  }, [])

  const now = new Date()
  const periodStart = (p: Period) => {
    switch (p) {
      case "daily": return new Date(now.getFullYear(), now.getMonth(), now.getDate())
      case "weekly": { const d = new Date(now); d.setDate(d.getDate() - d.getDay()); return d }
      case "monthly": return new Date(now.getFullYear(), now.getMonth(), 1)
      case "yearly": return new Date(now.getFullYear(), 0, 1)
    }
  }

  const start = periodStart(period)
  const filteredIncomes = incomes.filter((i) => i.date >= start)
  const filteredExpenses = expenses.filter((e) => e.date >= start)
  const totalIncome = filteredIncomes.reduce((s, i) => s + i.amount, 0)
  const totalExpense = filteredExpenses.reduce((s, e) => s + e.amount, 0)

  const catMap: Record<string, number> = {}
  filteredExpenses.forEach((e) => { catMap[e.category] = (catMap[e.category] || 0) + e.amount })
  const expenseByCat = Object.entries(catMap).sort((a, b) => b[1] - a[1]).slice(0, 8).map(([name, value], i) => ({ name: name || t("dashboard.others"), value, color: COLORS[i % COLORS.length] }))

  const months = ["Jan", "Feb", "Mar", "Apr", "Mei", "Jun", "Jul", "Agu", "Sep", "Okt", "Nov", "Des"]
  const trend: any[] = []
  for (let i = 11; i >= 0; i--) {
    const mStart = new Date(now.getFullYear(), now.getMonth() - i, 1)
    const mEnd = new Date(now.getFullYear(), now.getMonth() - i + 1, 0)
    trend.push({
      month: months[mStart.getMonth()],
      income: incomes.filter((inc) => inc.date >= mStart && inc.date <= mEnd).reduce((s, inc) => s + inc.amount, 0),
      expense: expenses.filter((e) => e.date >= mStart && e.date <= mEnd).reduce((s, e) => s + e.amount, 0),
    })
  }

  const periods: Period[] = ["daily", "weekly", "monthly", "yearly"]
  const periodLabels: Record<Period, string> = { daily: "Harian", weekly: "Mingguan", monthly: "Bulanan", yearly: "Tahunan" }

  if (loading) {
    return (
      <DashboardShell>
        <div className="max-w-4xl mx-auto space-y-6">
          <SkeletonLine width="180px" height={28} />
          <div className="flex gap-2">
            <SkeletonLine width="80px" height={36} className="rounded-xl" />
            <SkeletonLine width="80px" height={36} className="rounded-xl" />
            <SkeletonLine width="80px" height={36} className="rounded-xl" />
            <SkeletonLine width="80px" height={36} className="rounded-xl" />
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <SkeletonCard />
            <SkeletonCard />
            <SkeletonCard />
          </div>
          <div className="rounded-2xl border p-6 animate-pulse" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
            <SkeletonLine width="160px" height={20} />
            <div className="mt-4 h-64 flex items-end gap-3 px-4">
              {[30,50,35,60,40,55,45,65,38,52,48,42].map((h, i) => (
                <div key={i} className="flex-1 rounded-t" style={{ height: `${h}%`, backgroundColor: "var(--border)" }} />
              ))}
            </div>
          </div>
          <div className="rounded-2xl border p-6 animate-pulse" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
            <SkeletonLine width="180px" height={20} />
            <div className="mt-4 flex flex-col sm:flex-row items-center gap-6">
              <div className="w-44 h-44 rounded-full" style={{ backgroundColor: "var(--border)" }} />
              <div className="flex-1 space-y-3">
                {[1,2,3,4,5].map((i) => (
                  <div key={i} className="flex items-center gap-2">
                    <div className="h-3 w-3 rounded-full bg-skeleton" />
                    <SkeletonLine width="60%" height={14} />
                    <SkeletonLine width="80px" height={14} />
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </DashboardShell>
    )
  }

  return (
    <DashboardShell>
      <div className="max-w-4xl mx-auto space-y-6">
        <h1 className="text-2xl font-bold" style={{ color: "var(--text-primary)" }}>{t("nav.reports")}</h1>

        {/* Info card */}
        <div className="rounded-2xl border p-4 text-sm leading-relaxed" style={{ borderColor: "var(--border)", backgroundColor: "var(--primary-bg)", color: "var(--primary)" }}>
          <p>{t("reportsPage.desc")}</p>
        </div>

        {/* Period Filter */}
        <div className="flex gap-2">
          {periods.map((p) => (
            <button key={p} onClick={() => setPeriod(p)}
              className="rounded-xl px-4 py-2 text-sm font-medium transition-all"
              style={{ backgroundColor: period === p ? "var(--primary)" : "var(--bg-card)", color: period === p ? "#FFFFFF" : "var(--text-secondary)", border: period === p ? "none" : "1px solid var(--border)" }}
            >{periodLabels[p]}</button>
          ))}
        </div>

        {/* Summary Cards */}
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <div className="rounded-2xl border p-5" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
            <p className="text-sm" style={{ color: "var(--text-secondary)" }}>{t("dashboard.income")}</p>
            <p className="text-2xl font-bold mt-1" style={{ color: INCOME }}>{fmt(totalIncome)}</p>
          </div>
          <div className="rounded-2xl border p-5" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
            <p className="text-sm" style={{ color: "var(--text-secondary)" }}>{t("dashboard.expense")}</p>
            <p className="text-2xl font-bold mt-1" style={{ color: EXPENSE }}>{fmt(totalExpense)}</p>
          </div>
          <div className="rounded-2xl border p-5" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
            <p className="text-sm" style={{ color: "var(--text-secondary)" }}>{t("dashboard.remainingMonth")}</p>
            <p className="text-2xl font-bold mt-1" style={{ color: totalIncome - totalExpense >= 0 ? INCOME : EXPENSE }}>{fmt(totalIncome - totalExpense)}</p>
          </div>
        </div>

        {/* 12-Month Trend */}
        <div className="rounded-2xl border p-6" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
          <h3 className="text-base font-semibold" style={{ color: "var(--text-primary)" }}>{t("dashboard.trend6Month")}</h3>
          <div className="mt-4 h-64">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={trend}>
                <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" />
                <XAxis dataKey="month" tick={{ fontSize: 12, fill: "var(--text-secondary)" }} />
                <YAxis tick={{ fontSize: 12, fill: "var(--text-secondary)" }} tickFormatter={(v: number) => v >= 1000000 ? `${(v / 1000000).toFixed(1)}jt` : v >= 1000 ? `${(v / 1000).toFixed(0)}rb` : `${v}`} />
                <Tooltip formatter={(v: any) => fmt(Number(v))} />
                <Bar dataKey="income" name={t("dashboard.income")} radius={[6, 6, 0, 0]} fill={INCOME} />
                <Bar dataKey="expense" name={t("dashboard.expense")} radius={[6, 6, 0, 0]} fill={EXPENSE} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Expense by Category */}
        <div className="rounded-2xl border p-6" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
          <h3 className="text-base font-semibold" style={{ color: "var(--text-primary)" }}>{t("dashboard.expenseByCategory")}</h3>
          {expenseByCat.length === 0 ? (
            <p className="mt-4 text-sm text-center" style={{ color: "var(--text-muted)" }}>{t("dashboard.noDataThisMonth")}</p>
          ) : (
            <div className="mt-4 flex flex-col sm:flex-row items-center gap-6">
              <div className="w-44 h-44 shrink-0">
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie data={expenseByCat} dataKey="value" nameKey="name" cx="50%" cy="50%" outerRadius={80} innerRadius={50}>
                      {expenseByCat.map((_, i) => (<Cell key={i} fill={COLORS[i % COLORS.length]} />))}
                    </Pie>
                    <Tooltip formatter={(v: any) => fmt(Number(v))} />
                  </PieChart>
                </ResponsiveContainer>
              </div>
              <div className="flex-1 space-y-2 w-full">
                {expenseByCat.slice(0, 6).map((c, i) => (
                  <div key={i} className="flex items-center gap-2 text-sm">
                    <span className="h-3 w-3 rounded-full shrink-0" style={{ backgroundColor: c.color }} />
                    <span className="flex-1 truncate" style={{ color: "var(--text-secondary)" }}>{c.name}</span>
                    <span className="font-medium" style={{ color: "var(--text-primary)" }}>{fmt(c.value)}</span>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>
    </DashboardShell>
  )
}

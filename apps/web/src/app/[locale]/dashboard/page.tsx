"use client"

import { useEffect, useState } from "react"
import { collection, query, where, getDocs, getDoc, doc, Timestamp } from "firebase/firestore"
import { onAuthStateChanged } from "firebase/auth"
import { auth, db } from "@/lib/firebase"
import { useTranslations } from "next-intl"
import DashboardShell from "@/components/DashboardShell"
import { SkeletonCard, SkeletonLine, SkeletonBar } from "@/components/Skeleton"
import {
  PieChart, Pie, Cell, BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid,
} from "recharts"

const COLORS = ["#2E7D32", "#66BB6A", "#81C784", "#A5D6A7", "#C8E6C9", "#EF5350", "#FFA726", "#42A5F5", "#AB47BC", "#26A69A"]
const GREEN = "#2E7D32"
const GREEN_LIGHT = "#66BB6A"
const EXPENSE = "#EF5350"
const INCOME = "#4CAF50"

function formatRupiah(n: number) {
  return "Rp" + Math.floor(n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".")
}

export default function DashboardPage() {
  const t = useTranslations()
  const [loading, setLoading] = useState(true)
  const [uid, setUid] = useState<string | null>(null)
  const [familyId, setFamilyId] = useState<string | null>(null)
  const [wallets, setWallets] = useState<any[]>([])
  const [incomeMonth, setIncomeMonth] = useState(0)
  const [expenseMonth, setExpenseMonth] = useState(0)
  const [incomeLast, setIncomeLast] = useState(0)
  const [expenseLast, setExpenseLast] = useState(0)
  const [recentTx, setRecentTx] = useState<any[]>([])
  const [expenseByCategory, setExpenseByCategory] = useState<any[]>([])
  const [monthlyTrend, setMonthlyTrend] = useState<any[]>([])
  const [budgets, setBudgets] = useState<any[]>([])
  const [savings, setSavings] = useState<any[]>([])

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (u) => {
      try {
        if (!u) return
        setUid(u.uid)
        const snap = await getDoc(doc(db, "users", u.uid))
        const fid = snap.data()?.familyId ?? null
        setFamilyId(fid)
        if (!fid) return

        const now = new Date()
        const monthStart = new Date(now.getFullYear(), now.getMonth(), 1)
        const lastMonthStart = new Date(now.getFullYear(), now.getMonth() - 1, 1)

        const [walletSnap, incSnap, expSnap, budgetSnap, savingSnap] = await Promise.all([
          getDocs(query(collection(db, "wallets"), where("familyId", "==", fid))),
          getDocs(query(collection(db, "incomes"), where("familyId", "==", fid))),
          getDocs(query(collection(db, "expenses"), where("familyId", "==", fid))),
          getDocs(query(collection(db, "budgets"), where("familyId", "==", fid))),
          getDocs(query(collection(db, "savings"), where("familyId", "==", fid))),
        ])

        setWallets(walletSnap.docs.map((d) => ({ id: d.id, ...d.data() })))

        const parseDoc = (d: any) => ({
          id: d.id, amount: (d.data().amount as number) || 0, category: d.data().category || "",
          date: (d.data().date as Timestamp)?.toDate?.() || new Date(), note: d.data().note || "",
        })

        const allIncomes = incSnap.docs.map(parseDoc)
        const allExpenses = expSnap.docs.map(parseDoc)

        setIncomeMonth(allIncomes.filter((i) => i.date >= monthStart).reduce((s, i) => s + i.amount, 0))
        setIncomeLast(allIncomes.filter((i) => i.date >= lastMonthStart && i.date < monthStart).reduce((s, i) => s + i.amount, 0))
        setExpenseMonth(allExpenses.filter((e) => e.date >= monthStart).reduce((s, e) => s + e.amount, 0))
        setExpenseLast(allExpenses.filter((e) => e.date >= lastMonthStart && e.date < monthStart).reduce((s, e) => s + e.amount, 0))

        const allTx = [...allIncomes.slice(0, 5).map((i) => ({ ...i, type: "income" as const })), ...allExpenses.slice(0, 5).map((e) => ({ ...e, type: "expense" as const }))]
        allTx.sort((a, b) => b.date.getTime() - a.date.getTime())
        setRecentTx(allTx.slice(0, 10))

        const catMap: Record<string, number> = {}
        allExpenses.filter((e) => e.date >= monthStart).forEach((e) => { catMap[e.category] = (catMap[e.category] || 0) + e.amount })
        setExpenseByCategory(Object.entries(catMap).sort((a, b) => b[1] - a[1]).slice(0, 8).map(([name, value], i) => ({ name: name || t("dashboard.others"), value, color: COLORS[i % COLORS.length] })))

        const months = ["Jan", "Feb", "Mar", "Apr", "Mei", "Jun", "Jul", "Agu", "Sep", "Okt", "Nov", "Des"]
        const trend: any[] = []
        for (let i = 5; i >= 0; i--) {
          const mStart = new Date(now.getFullYear(), now.getMonth() - i, 1)
          const mEnd = new Date(now.getFullYear(), now.getMonth() - i + 1, 0)
          trend.push({ month: months[mStart.getMonth()], income: allIncomes.filter((inc) => inc.date >= mStart && inc.date <= mEnd).reduce((s, inc) => s + inc.amount, 0), expense: allExpenses.filter((e) => e.date >= mStart && e.date <= mEnd).reduce((s, e) => s + e.amount, 0) })
        }
        setMonthlyTrend(trend)
        setBudgets(budgetSnap.docs.map((d) => ({ id: d.id, ...d.data() })))
        setSavings(savingSnap.docs.map((d) => ({ id: d.id, ...d.data() })))
      } finally {
        setLoading(false)
      }
    })
    return unsub
  }, [t])

  const totalBalance = wallets.reduce((s, w) => s + w.balance, 0)
  const incChange = incomeLast > 0 ? ((incomeMonth - incomeLast) / incomeLast) * 100 : 0
  const expChange = expenseLast > 0 ? ((expenseMonth - expenseLast) / expenseLast) * 100 : 0

  if (loading) {
    return (
      <DashboardShell>
        <div className="space-y-6 lg:space-y-8">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-5">
            {[...Array(4)].map((_, i) => <SkeletonCard key={i} />)}
          </div>
          <div className="grid grid-cols-1 lg:grid-cols-5 gap-5">
            <div className="lg:col-span-2 rounded-2xl border p-6 animate-pulse" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
              <SkeletonLine width="40%" height={18} />
              <div className="mt-8 flex items-center gap-4">
                <div className="w-40 h-40 rounded-full bg-gray-100" />
                <div className="flex-1 space-y-3">
                  {[...Array(4)].map((_, i) => <SkeletonLine key={i} width={`${50 + i * 10}%`} height={14} />)}
                </div>
              </div>
            </div>
            <div className="lg:col-span-3 rounded-2xl border p-6 animate-pulse" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
              <SkeletonLine width="30%" height={18} />
              <div className="mt-4 h-56 rounded bg-gray-100" />
            </div>
          </div>
          <div className="rounded-2xl border p-6 animate-pulse" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
            <SkeletonLine width="35%" height={18} />
            <div className="mt-4 space-y-3">
              {[...Array(5)].map((_, i) => (
                <div key={i} className="flex items-center gap-3">
                  <div className="h-9 w-9 rounded-xl bg-gray-100" />
                  <div className="flex-1 space-y-1">
                    <SkeletonLine width={`${40 + i * 8}%`} height={14} />
                    <SkeletonLine width={`${20 + i * 5}%`} height={12} />
                  </div>
                  <SkeletonLine width="25%" height={14} />
                </div>
              ))}
            </div>
          </div>
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
            {[...Array(2)].map((_, i) => (
              <div key={i} className="rounded-2xl border p-6 animate-pulse" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
                <SkeletonLine width="30%" height={18} />
                <div className="mt-4 space-y-4">
                  {[...Array(3)].map((_, j) => <SkeletonBar key={j} pct={30 + j * 20} />)}
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
      {!familyId && (
        <div className="flex items-center gap-2 rounded-xl border px-4 py-3 text-sm mb-6" style={{ borderColor: "var(--border)", backgroundColor: "var(--warning-bg)", color: "var(--warning-text)" }}>
          <span>👨‍👩‍👧‍👦</span>
          <span>{t("dashboard.noFamilyDesc")}</span>
        </div>
      )}

      <div className="space-y-6 lg:space-y-8">
        {/* Summary Cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-5">
          <SummaryCard label={t("dashboard.totalBalance")} value={formatRupiah(totalBalance)} sub={`${wallets.length} ${t("dashboard.walletsCount")}`} icon="👛" />
          <SummaryCard label={t("dashboard.incomeMonth")} value={formatRupiah(incomeMonth)} sub={`${incChange >= 0 ? "▲" : "▼"} ${Math.abs(incChange).toFixed(1)}% ${t("dashboard.fromLastMonth")}`} color={INCOME} icon="📈" />
          <SummaryCard label={t("dashboard.expenseMonth")} value={formatRupiah(expenseMonth)} sub={`${expChange >= 0 ? "▲" : "▼"} ${Math.abs(expChange).toFixed(1)}% ${t("dashboard.fromLastMonth")}`} color={EXPENSE} icon="📉" />
          <SummaryCard label={t("dashboard.remainingMonth")} value={formatRupiah(incomeMonth - expenseMonth)} sub={t("dashboard.incomeExpense")} color={incomeMonth - expenseMonth >= 0 ? INCOME : EXPENSE} icon="💵" />
        </div>

        {/* Charts */}
        <div className="grid grid-cols-1 lg:grid-cols-5 gap-5">
          <div className="lg:col-span-2 rounded-2xl border p-6" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
            <h3 className="text-base font-semibold" style={{ color: "var(--text-primary)" }}>{t("dashboard.expenseByCategory")}</h3>
            {expenseByCategory.length === 0 ? (
              <p className="mt-8 text-sm text-center" style={{ color: "var(--text-muted)" }}>{t("dashboard.noDataThisMonth")}</p>
            ) : (
              <div className="mt-4 flex items-center gap-4">
                <div className="w-40 h-40 shrink-0">
                  <ResponsiveContainer width="100%" height="100%">
                    <PieChart>
                      <Pie data={expenseByCategory} dataKey="value" nameKey="name" cx="50%" cy="50%" outerRadius={70} innerRadius={45}>
                        {expenseByCategory.map((_, i) => (<Cell key={i} fill={COLORS[i % COLORS.length]} />))}
                      </Pie>
                      <Tooltip formatter={(v: any) => formatRupiah(Number(v))} />
                    </PieChart>
                  </ResponsiveContainer>
                </div>
                <div className="flex-1 space-y-1.5">
                  {expenseByCategory.slice(0, 5).map((c, i) => (
                    <div key={i} className="flex items-center gap-2 text-xs">
                      <span className="h-2.5 w-2.5 rounded-full shrink-0" style={{ backgroundColor: c.color }} />
                      <span className="flex-1 truncate" style={{ color: "var(--text-secondary)" }}>{c.name}</span>
                      <span className="font-medium" style={{ color: "var(--text-primary)" }}>{formatRupiah(c.value)}</span>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>

          <div className="lg:col-span-3 rounded-2xl border p-6" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
            <h3 className="text-base font-semibold" style={{ color: "var(--text-primary)" }}>{t("dashboard.trend6Month")}</h3>
            <div className="mt-4 h-56">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={monthlyTrend}>
                  <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" />
                  <XAxis dataKey="month" tick={{ fontSize: 12, fill: "var(--text-secondary)" }} />
                  <YAxis tick={{ fontSize: 12, fill: "var(--text-secondary)" }} tickFormatter={(v: number) => v >= 1000000 ? `${(v / 1000000).toFixed(1)}jt` : v >= 1000 ? `${(v / 1000).toFixed(0)}rb` : `${v}`} />
                  <Tooltip formatter={(v: any) => formatRupiah(Number(v))} />
                  <Bar dataKey="income" name={t("dashboard.income")} radius={[6, 6, 0, 0]} fill={INCOME} />
                  <Bar dataKey="expense" name={t("dashboard.expense")} radius={[6, 6, 0, 0]} fill={EXPENSE} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </div>
        </div>

        {/* Recent Transactions */}
        <div className="rounded-2xl border" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
          <div className="flex items-center justify-between p-6 pb-0">
            <h3 className="text-base font-semibold" style={{ color: "var(--text-primary)" }}>{t("dashboard.recentTransactions")}</h3>
            <span className="text-xs" style={{ color: "var(--text-muted)" }}>{t("dashboard.last10")}</span>
          </div>
          {recentTx.length === 0 ? (
            <p className="p-6 text-sm text-center" style={{ color: "var(--text-muted)" }}>{t("dashboard.noTransactions")}</p>
          ) : (
            <div className="mt-4 divide-y" style={{ borderColor: "var(--border)" }}>
              {recentTx.map((tx: any, i: number) => (
                <div key={tx.id || i} className="flex items-center justify-between px-6 py-3.5 hover-surface transition-colors">
                  <div className="flex items-center gap-3 min-w-0">
                    <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl text-sm" style={{ backgroundColor: tx.type === "income" ? "var(--primary-bg)" : "var(--expense-bg)" }}>
                      {tx.type === "income" ? "📥" : "📤"}
                    </div>
                    <div className="min-w-0">
                      <p className="text-sm font-medium truncate" style={{ color: "var(--text-primary)" }}>{tx.category}</p>
                      <p className="text-xs truncate" style={{ color: "var(--text-muted)" }}>{tx.note || new Date(tx.date).toLocaleDateString("id-ID")}</p>
                    </div>
                  </div>
                  <span className={`text-sm font-semibold shrink-0 ml-4 ${tx.type === "income" ? "text-income" : "text-expense"}`}>
                    {tx.type === "income" ? "+" : "-"}{formatRupiah(tx.amount)}
                  </span>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Budget & Savings */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
          <div className="rounded-2xl border p-6" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
            <h3 className="text-base font-semibold" style={{ color: "var(--text-primary)" }}>{t("dashboard.budget")}</h3>
            {budgets.length === 0 ? (
              <p className="mt-4 text-sm" style={{ color: "var(--text-muted)" }}>{t("dashboard.noBudget")}</p>
            ) : (
              <div className="mt-4 space-y-4">
                {budgets.map((b: any) => {
                  const pct = b.amount > 0 ? Math.min((b.usedAmount / b.amount) * 100, 100) : 0
                  return (
                    <div key={b.id}>
                      <div className="flex justify-between text-sm mb-1">
                        <span style={{ color: "var(--text-primary)" }}>{b.category}</span>
                        <span style={{ color: "var(--text-secondary)" }}>{formatRupiah(b.usedAmount)} / {formatRupiah(b.amount)}</span>
                      </div>
                      <div className="h-2.5 w-full rounded-full" style={{ backgroundColor: "var(--surface-soft)" }}>
                        <div className="h-full rounded-full transition-all duration-300" style={{ width: `${pct}%`, backgroundColor: pct >= 100 ? EXPENSE : GREEN_LIGHT }} />
                      </div>
                    </div>
                  )
                })}
              </div>
            )}
          </div>

          <div className="rounded-2xl border p-6" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
            <h3 className="text-base font-semibold" style={{ color: "var(--text-primary)" }}>{t("dashboard.savings")}</h3>
            {savings.length === 0 ? (
              <p className="mt-4 text-sm" style={{ color: "var(--text-muted)" }}>{t("dashboard.noSavings")}</p>
            ) : (
              <div className="mt-4 space-y-4">
                {savings.map((s: any) => {
                  const pct = s.targetAmount > 0 ? Math.min((s.currentAmount / s.targetAmount) * 100, 100) : 0
                  return (
                    <div key={s.id}>
                      <div className="flex justify-between text-sm mb-1">
                        <span style={{ color: "var(--text-primary)" }}>{s.name}</span>
                        <span style={{ color: "var(--text-secondary)" }}>{formatRupiah(s.currentAmount)} / {formatRupiah(s.targetAmount)}</span>
                      </div>
                      <div className="h-2.5 w-full rounded-full" style={{ backgroundColor: "var(--surface-soft)" }}>
                        <div className="h-full rounded-full transition-all duration-300" style={{ width: `${pct}%`, backgroundColor: GREEN }} />
                      </div>
                    </div>
                  )
                })}
              </div>
            )}
          </div>
        </div>
      </div>
    </DashboardShell>
  )
}

function SummaryCard({ label, value, sub, icon, color }: { label: string; value: string; sub: string; icon: string; color?: string }) {
  return (
    <div className="rounded-2xl border p-6 transition-all duration-200 hover:shadow-md" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
      <div className="flex items-center justify-between">
        <p className="text-sm font-medium" style={{ color: "var(--text-secondary)" }}>{label}</p>
        <div className="flex h-10 w-10 items-center justify-center rounded-xl" style={{ backgroundColor: "var(--primary-bg)" }}>{icon}</div>
      </div>
      <p className="mt-3 text-2xl font-bold" style={{ color: color || "var(--text-primary)" }}>{value}</p>
      <p className="mt-1 text-xs" style={{ color: "var(--text-muted)" }}>{sub}</p>
    </div>
  )
}

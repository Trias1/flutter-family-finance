// Development-only sample data for reviewing the dashboard layout without
// touching Firestore. Loaded only when NODE_ENV is "development" and the URL
// has ?demo=1; production builds drop it.

import type { Bill, Budget, Debt, Member, Saving, Tx } from "@/lib/family-data"
import { monthKey } from "@/lib/money"

function seeded(seed: number) {
  let s = seed
  return () => {
    s = (s * 16807) % 2147483647
    return (s - 1) / 2147483646
  }
}

export function buildDemoData() {
  const rand = seeded(42)
  const now = new Date()
  const members: Member[] = [
    { id: "m1", name: "Trias" },
    { id: "m2", name: "Dewi" },
  ]
  const expenseCats: [string, number][] = [
    ["Kebutuhan rumah", 1_400_000], ["Makan di luar", 450_000], ["Transportasi", 600_000],
    ["Tagihan", 900_000], ["Pendidikan", 750_000], ["Kesehatan", 250_000], ["Hiburan", 300_000],
  ]
  const incomes: Tx[] = []
  const expenses: Tx[] = []
  let id = 0
  for (let m = 5; m >= 0; m--) {
    const base = new Date(now.getFullYear(), now.getMonth() - m, 1)
    const days = m === 0 ? now.getDate() : new Date(base.getFullYear(), base.getMonth() + 1, 0).getDate()
    incomes.push({ id: `i${id++}`, kind: "income", amount: 9_500_000, category: "Gaji", note: "Gaji bulanan", date: new Date(base.getFullYear(), base.getMonth(), Math.min(25, days)), userId: "m1" })
    if (rand() > 0.4) incomes.push({ id: `i${id++}`, kind: "income", amount: Math.round(1_000_000 + rand() * 2_000_000), category: "Usaha", note: "Jualan online", date: new Date(base.getFullYear(), base.getMonth(), Math.ceil(rand() * days)), userId: "m2" })
    for (const [category, budget] of expenseCats) {
      const count = 2 + Math.floor(rand() * 4)
      for (let k = 0; k < count; k++) {
        expenses.push({
          id: `e${id++}`, kind: "expense", category,
          amount: Math.round((budget / count) * (0.6 + rand() * 0.7) / 500) * 500,
          note: rand() > 0.5 ? "" : ["Indomaret", "Gojek", "PLN", "Shopee", "Apotek", "SPP"][Math.floor(rand() * 6)],
          date: new Date(base.getFullYear(), base.getMonth(), Math.ceil(rand() * days)),
          userId: rand() > 0.5 ? "m1" : "m2",
        })
      }
    }
  }
  const key = monthKey(now)
  const thisMonth = expenses.filter((e) => monthKey(e.date) === key)
  const budgets: Budget[] = expenseCats.slice(0, 5).map(([category, amount], i) => ({
    id: `b${i}`, month: key, category, budgetAmount: amount,
    usedAmount: thisMonth.filter((e) => e.category === category).reduce((s, e) => s + e.amount, 0),
  }))
  const savings: Saving[] = [
    { id: "s1", name: "Dana darurat", category: "emergency", targetAmount: 30_000_000, currentAmount: 18_400_000, targetDate: new Date(now.getFullYear() + 1, 5, 1), goldGrams: null },
    { id: "s2", name: "Emas Antam", category: "gold", targetAmount: 15_000_000, currentAmount: 6_250_000, targetDate: new Date(now.getFullYear() + 1, 11, 1), goldGrams: 4.5 },
    { id: "s3", name: "Liburan keluarga", category: "vacation", targetAmount: 8_000_000, currentAmount: 8_000_000, targetDate: new Date(now.getFullYear(), now.getMonth() + 2, 1), goldGrams: null },
  ]
  const debts: Debt[] = [
    { id: "d1", type: "hutang", personName: "Cicilan motor", description: "Leasing 24x", amount: 18_000_000, remainingAmount: 9_750_000, dueDate: new Date(now.getFullYear(), now.getMonth(), now.getDate() + 5), status: "active" },
    { id: "d2", type: "piutang", personName: "Budi", description: "Pinjam untuk servis mobil", amount: 2_500_000, remainingAmount: 1_000_000, dueDate: new Date(now.getFullYear(), now.getMonth(), now.getDate() - 3), status: "active" },
    { id: "d3", type: "hutang", personName: "Arisan", description: "", amount: 1_200_000, remainingAmount: 0, dueDate: null, status: "paid" },
  ]
  const bills: Bill[] = [
    { id: "x1", name: "Internet IndiHome", amount: 385_000, dueDate: new Date(now.getFullYear(), now.getMonth(), now.getDate() + 3), status: "pending", repeatType: "monthly" },
    { id: "x2", name: "BPJS Kesehatan", amount: 450_000, dueDate: new Date(now.getFullYear(), now.getMonth(), now.getDate() + 9), status: "pending", repeatType: "monthly" },
    { id: "x3", name: "Air PDAM", amount: 120_000, dueDate: new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1), status: "pending", repeatType: "monthly" },
  ]
  return { incomes, expenses, budgets, savings, debts, bills, members }
}

export function buildDemoAdminOverview() {
  const rand = seeded(7)
  const now = Date.now()
  const names = ["Trias", "Dewi", "Budi", "Sari", "Andi", "Rina", "Joko", "Maya", "Fajar", "Lina", "Hadi", "Tari"]
  const versions = ["1.1.10+14", "1.1.10+14", "1.1.9+13", "1.1.8+12"]
  const users = names.map((name, i) => {
    const web = i % 4 === 0
    const lastSeenAt = now - Math.floor(rand() * (i < 3 ? 90_000 : 5 * 86_400_000))
    const version = web ? "1.1.10+14" : versions[Math.floor(rand() * versions.length)]
    return {
      id: `u${i}`,
      name,
      devicesCount: 1 + Math.floor(rand() * 2),
      latestSource: web ? "web" : "android",
      latestDeviceName: web ? "Chrome Win32" : ["Samsung SM-A546E", "Xiaomi 23021RAA2Y", "OPPO CPH2591"][i % 3],
      appVersionLabel: version,
      online: now - lastSeenAt < 120_000,
      outdated: !web && version !== "1.1.10+14",
      activeToday: now - lastSeenAt < 86_400_000,
      lastSeenAt,
    }
  })
  const growth = Array.from({ length: 14 }, (_, i) => ({
    day: new Date(now - (13 - i) * 86_400_000).toISOString().slice(5, 10),
    users: Math.floor(rand() * 3),
    active: 2 + Math.floor(rand() * 8),
  }))
  const versionCounts = new Map<string, number>()
  for (const u of users) versionCounts.set(u.appVersionLabel, (versionCounts.get(u.appVersionLabel) ?? 0) + 1)
  return {
    totalUsers: users.length,
    onlineUsers: users.filter((u) => u.online).length,
    activeToday: users.filter((u) => u.activeToday).length,
    outdatedUsers: users.filter((u) => u.outdated).length,
    activeDevices: users.reduce((s, u) => s + u.devicesCount, 0),
    latestVersionName: "1.1.10",
    latestVersionCode: 14,
    growth,
    versions: Array.from(versionCounts, ([name, value]) => ({ name, value })).sort((a, b) => b.value - a.value),
    users: users.sort((a, b) => b.lastSeenAt - a.lastSeenAt),
  }
}

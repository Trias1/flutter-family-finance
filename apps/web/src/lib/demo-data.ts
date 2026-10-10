// Development-only sample data for reviewing the dashboard layout without
// touching Firestore. Loaded only when NODE_ENV is "development" and the URL
// has ?demo=1; production builds drop it.

import type { AdminDevice, AdminOverview, AdminUser, OverviewQuery } from "@/lib/admin-types"
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
    id: `b${i}`, month: key, category, budgetAmount: amount, rolloverAmount: 0,
    usedAmount: thisMonth.filter((e) => e.category === category).reduce((s, e) => s + e.amount, 0),
  }))
  const savings: Saving[] = [
    { id: "s1", name: "Dana darurat", category: "emergency", targetAmount: 30_000_000, currentAmount: 18_400_000, targetDate: new Date(now.getFullYear() + 1, 5, 1), createdAt: new Date(now.getFullYear() - 1, 5, 1), goldGrams: null },
    { id: "s2", name: "Emas Antam", category: "gold", targetAmount: 15_000_000, currentAmount: 6_250_000, targetDate: new Date(now.getFullYear() + 1, 11, 1), createdAt: new Date(now.getFullYear() - 1, 0, 1), goldGrams: 4.5 },
    { id: "s3", name: "Liburan keluarga", category: "vacation", targetAmount: 8_000_000, currentAmount: 8_000_000, targetDate: new Date(now.getFullYear(), now.getMonth() + 2, 1), createdAt: null, goldGrams: null },
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

export function buildDemoAdminOverview(query: OverviewQuery, pageSize: number): AdminOverview {
  const rand = seeded(7)
  const now = Date.now()
  const names = ["Trias", "Dewi", "Budi", "Sari", "Andi", "Rina", "Joko", "Maya", "Fajar", "Lina", "Hadi", "Tari"]
  const versions: [string, number][] = [["1.1.10", 14], ["1.1.10", 14], ["1.1.9", 13], ["1.1.8", 12]]
  const phones = [["Samsung", "SM-A546E"], ["Xiaomi", "23021RAA2Y"], ["OPPO", "CPH2591"]]
  const users: AdminUser[] = names.map((name, i) => {
    const lastSeenAt = now - Math.floor(rand() * (i < 3 ? 90_000 : 5 * 86_400_000))
    const [versionName, versionCode] = versions[Math.floor(rand() * versions.length)]
    const devices: AdminDevice[] = [
      { id: `a${i}`, platform: "android", brand: phones[i % 3][0], model: phones[i % 3][1], osVersion: String(12 + (i % 3)), appVersionName: versionName, appVersionCode: versionCode, lastSeenAt },
    ]
    if (i % 4 === 0) devices.push({ id: `w${i}`, platform: "web", brand: "Chrome", model: "Win32", osVersion: "Web", appVersionName: "1.1.10", appVersionCode: 14, lastSeenAt: lastSeenAt - 3_600_000 })
    return {
      id: `u${i}`,
      name,
      role: i === 0 ? "superadmin" : i === 1 ? "admin" : "member",
      disabled: i === 7,
      devices,
      hasWeb: i % 4 === 0,
      latestSource: "android",
      appVersionLabel: `${versionName}+${versionCode}`,
      online: now - lastSeenAt < 120_000,
      outdated: versionCode < 14,
      lastSeenAt,
    }
  })
  users.sort((a, b) => (b.lastSeenAt ?? 0) - (a.lastSeenAt ?? 0))
  const growth = Array.from({ length: 14 }, (_, i) => ({
    day: new Date(now - (13 - i) * 86_400_000).toISOString().slice(5, 10),
    users: Math.floor(rand() * 3),
    active: 2 + Math.floor(rand() * 8),
  }))
  const versionCounts = new Map<string, number>()
  for (const u of users) versionCounts.set(u.appVersionLabel, (versionCounts.get(u.appVersionLabel) ?? 0) + 1)
  // Mirrors the server's search and filters so the layout can be reviewed with them.
  const q = query.q.toLowerCase()
  const matching = users.filter((u) => {
    if (q && !u.name.toLowerCase().includes(q)) return false
    if (query.filter === "online") return u.online
    if (query.filter === "web") return u.hasWeb
    if (query.filter === "outdated") return u.outdated
    if (query.filter === "disabled") return u.disabled
    return true
  })
  return {
    stats: {
      totalUsers: users.length,
      totalFamilies: 5,
      onlineUsers: users.filter((u) => u.online).length,
      activeToday: users.filter((u) => now - (u.lastSeenAt ?? 0) < 86_400_000).length,
      outdatedUsers: users.filter((u) => u.outdated).length,
      activeDevices: users.reduce((s, u) => s + u.devices.length, 0),
      latestVersionName: "1.1.10",
      latestVersionCode: 14,
      webVersionName: "1.1.10",
      webVersionCode: 14,
    },
    growth,
    release: { forceUpdate: false, releaseNotes: "Perbaikan dan fitur baru." },
    announcement: { active: false, messageId: "", messageEn: "", tone: "info" },
    versions: Array.from(versionCounts, ([name, value]) => ({ name, value })).sort((a, b) => b.value - a.value),
    users: matching.slice((query.page - 1) * pageSize, query.page * pageSize),
    page: query.page,
    pageSize,
    total: matching.length,
  }
}

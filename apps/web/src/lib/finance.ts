import type { Budget, Tx } from "@/lib/family-data"
import { monthKey, startOfMonth } from "@/lib/money"

// Moving money into savings is not spending; the Android app counts it the
// same way, so both show the same totals.
export function isSavingsTransfer(category: string) {
  return category === "Tabungan" || category === "Savings"
}

export function spending(expenses: Tx[]) {
  return expenses.filter((e) => !isSavingsTransfer(e.category))
}

export function sumInRange(items: Tx[], from: Date, to: Date) {
  let total = 0
  for (const item of items) if (item.date >= from && item.date < to) total += item.amount
  return total
}

export function monthTotals(incomes: Tx[], expenses: Tx[], ref: Date, offset = 0) {
  const from = startOfMonth(ref, offset)
  const to = startOfMonth(ref, offset + 1)
  const income = sumInRange(incomes, from, to)
  const expense = sumInRange(spending(expenses), from, to)
  return { income, expense, net: income - expense, from, to }
}

export function cashflowSeries(incomes: Tx[], expenses: Tx[], ref: Date, months: number, locale: string) {
  const fmt = new Intl.DateTimeFormat(locale, { month: "short" })
  const full = new Intl.DateTimeFormat(locale, { month: "long", year: "numeric" })
  return Array.from({ length: months }, (_, i) => {
    const offset = i - (months - 1)
    const totals = monthTotals(incomes, expenses, ref, offset)
    return { label: fmt.format(totals.from), title: full.format(totals.from), income: totals.income, expense: totals.expense }
  })
}

export function budgetsForMonth(budgets: Budget[], ref: Date) {
  const key = monthKey(ref)
  return budgets.filter((b) => b.month === key && b.budgetAmount > 0 && !isSavingsTransfer(b.category))
}

export function byCategory(items: Tx[], from: Date, to: Date) {
  const map = new Map<string, number>()
  for (const item of items) {
    if (item.date < from || item.date >= to) continue
    map.set(item.category, (map.get(item.category) ?? 0) + item.amount)
  }
  return Array.from(map, ([category, amount]) => ({ category, amount })).sort((a, b) => b.amount - a.amount)
}

/** Spending per member who recorded it, largest first. */
export function byMember(items: Tx[], from: Date, to: Date) {
  const map = new Map<string, number>()
  for (const item of items) {
    if (item.date < from || item.date >= to) continue
    map.set(item.userId, (map.get(item.userId) ?? 0) + item.amount)
  }
  return Array.from(map, ([userId, amount]) => ({ userId, amount })).sort((a, b) => b.amount - a.amount)
}

/** Whole months from the start of `from`'s month to the start of `to`'s month. */
export function monthsBetween(from: Date, to: Date) {
  return (to.getFullYear() - from.getFullYear()) * 12 + (to.getMonth() - from.getMonth())
}

/**
 * Pace of a savings goal with a target date: how much is still needed per
 * month, and whether progress lags a straight line from creation to target.
 */
export function savingsPace(goal: { targetAmount: number; currentAmount: number; targetDate: Date | null; createdAt: Date | null }, now: Date) {
  if (!goal.targetDate || goal.targetAmount <= 0 || goal.currentAmount >= goal.targetAmount) return null
  const remaining = goal.targetAmount - goal.currentAmount
  if (goal.targetDate <= now) return { perMonth: remaining, monthsLeft: 0, behind: true, overdue: true }
  // Counting the current month too, so a target later this month still needs one month's worth.
  const monthsLeft = Math.max(1, monthsBetween(now, goal.targetDate) + (goal.targetDate.getDate() >= now.getDate() ? 0 : -1) + 1)
  let behind = false
  if (goal.createdAt && goal.createdAt < goal.targetDate) {
    const elapsed = (now.getTime() - goal.createdAt.getTime()) / (goal.targetDate.getTime() - goal.createdAt.getTime())
    // A little slack so a goal is not flagged for being a few days late.
    behind = goal.currentAmount / goal.targetAmount < Math.min(1, Math.max(0, elapsed)) - 0.05
  }
  return { perMonth: remaining / monthsLeft, monthsLeft, behind, overdue: false }
}

/** Percent change, or null when there is nothing to compare against. */
export function change(current: number, previous: number) {
  if (previous <= 0) return null
  return ((current - previous) / previous) * 100
}

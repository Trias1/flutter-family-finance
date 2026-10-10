import type { Budget, Tx } from "@/lib/family-data"
import { monthKey, startOfMonth } from "@/lib/money"

export function sumInRange(items: Tx[], from: Date, to: Date) {
  let total = 0
  for (const item of items) if (item.date >= from && item.date < to) total += item.amount
  return total
}

export function monthTotals(incomes: Tx[], expenses: Tx[], ref: Date, offset = 0) {
  const from = startOfMonth(ref, offset)
  const to = startOfMonth(ref, offset + 1)
  const income = sumInRange(incomes, from, to)
  const expense = sumInRange(expenses, from, to)
  return { income, expense, net: income - expense, from, to }
}

export function cashflowSeries(incomes: Tx[], expenses: Tx[], ref: Date, months: number, locale: string) {
  const fmt = new Intl.DateTimeFormat(locale, { month: "short" })
  return Array.from({ length: months }, (_, i) => {
    const offset = i - (months - 1)
    const totals = monthTotals(incomes, expenses, ref, offset)
    return { label: fmt.format(totals.from), income: totals.income, expense: totals.expense }
  })
}

export function budgetsForMonth(budgets: Budget[], ref: Date) {
  const key = monthKey(ref)
  return budgets.filter((b) => b.month === key && b.budgetAmount > 0)
}

export function byCategory(items: Tx[], from: Date, to: Date) {
  const map = new Map<string, number>()
  for (const item of items) {
    if (item.date < from || item.date >= to) continue
    map.set(item.category, (map.get(item.category) ?? 0) + item.amount)
  }
  return Array.from(map, ([category, amount]) => ({ category, amount })).sort((a, b) => b.amount - a.amount)
}

/** Percent change, or null when there is nothing to compare against. */
export function change(current: number, previous: number) {
  if (previous <= 0) return null
  return ((current - previous) / previous) * 100
}

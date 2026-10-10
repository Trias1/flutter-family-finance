import { NextRequest, NextResponse } from "next/server"

import { adminAuth, adminDb } from "@/lib/firebase-admin"

export const runtime = "nodejs"

const openAiApiKey = process.env.OPENAI_API_KEY
const openAiModel = process.env.OPENAI_MODEL ?? "gpt-4.1-mini"
const requestLimitMs = 30_000
const maxMessageLength = 1200

type ChatHistoryItem = {
  role?: unknown
  content?: unknown
}

function sanitizeHistory(raw: unknown) {
  if (!Array.isArray(raw)) return []
  return raw
    .filter((item): item is ChatHistoryItem => typeof item === "object" && item !== null)
    .map((item) => ({
      role: item.role === "assistant" ? "assistant" : "user",
      content: String(item.content ?? "").slice(0, 2000),
    }))
    .filter((item) => item.content.trim().length > 0)
    .slice(-8)
}

function toMillis(value: any) {
  if (!value) return 0
  if (typeof value.toMillis === "function") return value.toMillis()
  if (typeof value._seconds === "number") return value._seconds * 1000
  if (typeof value.seconds === "number") return value.seconds * 1000
  return 0
}

function asNumber(value: any) {
  return typeof value === "number" && Number.isFinite(value) ? value : Number(value ?? 0) || 0
}

function monthKey(date = new Date()) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}`
}

async function getFinanceSummary(uid: string) {
  if (!adminDb) throw new Error("Firestore is not configured")

  const userSnap = await adminDb.collection("users").doc(uid).get()
  const user = userSnap.data() ?? {}
  const familyId = typeof user.familyId === "string" && user.familyId.length > 0 ? user.familyId : uid
  const currentMonth = monthKey()

  const [incomesSnap, expensesSnap, budgetsSnap, savingsSnap, billsSnap, debtsSnap] = await Promise.all([
    adminDb.collection("incomes").where("familyId", "==", familyId).get(),
    adminDb.collection("expenses").where("familyId", "==", familyId).get(),
    adminDb.collection("budgets").where("familyId", "==", familyId).where("month", "==", currentMonth).get(),
    adminDb.collection("savings").where("familyId", "==", familyId).get(),
    adminDb.collection("bills").where("familyId", "==", familyId).get(),
    adminDb.collection("debts").where("familyId", "==", familyId).get(),
  ])

  const incomes = incomesSnap.docs.map((doc) => doc.data())
  const expenses = expensesSnap.docs.map((doc) => doc.data())
  const budgets = budgetsSnap.docs.map((doc) => doc.data())
  const savings = savingsSnap.docs.map((doc) => doc.data())
  const bills = billsSnap.docs.map((doc) => doc.data())
  const debts = debtsSnap.docs.map((doc) => doc.data())

  const expenseByCategory = new Map<string, number>()
  for (const expense of expenses) {
    const category = String(expense.category || "Lainnya")
    expenseByCategory.set(category, (expenseByCategory.get(category) ?? 0) + asNumber(expense.amount))
  }

  return {
    scope: familyId === uid ? "personal" : "family",
    currency: "IDR",
    period: currentMonth,
    totalIncome: incomes.reduce((sum, item) => sum + asNumber(item.amount), 0),
    totalExpense: expenses.reduce((sum, item) => sum + asNumber(item.amount), 0),
    totalSavings: savings.reduce((sum, item) => sum + asNumber(item.currentAmount), 0),
    topExpenseCategories: Array.from(expenseByCategory.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([category, amount]) => ({ category, amount: Math.round(amount) })),
    budgets: budgets.slice(0, 8).map((budget) => ({
      category: String(budget.category || "Budget"),
      limit: Math.round(asNumber(budget.limitAmount ?? budget.amount ?? budget.budgetAmount)),
      spent: Math.round(asNumber(budget.spentAmount ?? budget.usedAmount)),
      remaining: Math.round(asNumber(budget.remaining)),
    })),
    goals: savings.slice(0, 8).map((saving) => ({
      name: String(saving.name || "Goal"),
      targetAmount: Math.round(asNumber(saving.targetAmount)),
      currentAmount: Math.round(asNumber(saving.currentAmount)),
      category: typeof saving.category === "string" ? saving.category : undefined,
    })),
    upcomingBills: bills
      .filter((bill) => String(bill.status ?? "").toLowerCase() !== "paid")
      .sort((a, b) => toMillis(a.dueDate) - toMillis(b.dueDate))
      .slice(0, 5)
      .map((bill) => ({
        name: String(bill.name || bill.title || "Tagihan"),
        amount: Math.round(asNumber(bill.amount)),
        dueDate: toMillis(bill.dueDate) ? new Date(toMillis(bill.dueDate)).toISOString().slice(0, 10) : "",
      })),
    debts: debts.slice(0, 8).map((debt) => ({
      name: String(debt.name || debt.personName || "Hutang"),
      amount: Math.round(asNumber(debt.amount)),
      remainingAmount: Math.round(asNumber(debt.remainingAmount ?? debt.amount)),
      status: typeof debt.status === "string" ? debt.status : undefined,
    })),
  }
}

async function createOpenAiResponse(message: string, history: Array<{ role: string; content: string }>, summary: Awaited<ReturnType<typeof getFinanceSummary>>) {
  if (!openAiApiKey) {
    return {
      reply: "AI belum aktif. Tambahkan OPENAI_API_KEY di environment Vercel/server, lalu deploy ulang. Tidak perlu login ChatGPT di aplikasi user.",
      responseId: null,
      provider: "openai",
      model: openAiModel,
      configured: false,
    }
  }

  const controller = new AbortController()
  const timeout = setTimeout(() => controller.abort(), requestLimitMs)

  try {
    const input = [
      {
        role: "system",
        content: `Kamu adalah AI Advisor untuk Family Finance Manager. Jawab Bahasa Indonesia, santai, ringkas, dan praktis. Gunakan hanya data ringkasan yang diberikan. Jangan mengarang angka. Jangan mengaku sebagai penasihat keuangan profesional. Ringkasan finance: ${JSON.stringify(summary)}`,
      },
      ...history,
      { role: "user", content: message },
    ]

    const res = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        authorization: `Bearer ${openAiApiKey}`,
        "content-type": "application/json",
      },
      signal: controller.signal,
      body: JSON.stringify({
        model: openAiModel,
        input,
        temperature: 0.4,
        max_output_tokens: 900,
      }),
    })

    const json = await res.json().catch(() => ({}))
    if (!res.ok) {
      const detail = json?.error?.message || "OpenAI gagal merespons."
      return { reply: `AI sedang bermasalah (${res.status}). ${detail}`, responseId: null, provider: "openai", model: openAiModel, configured: true }
    }

    const text = typeof json.output_text === "string"
      ? json.output_text.trim()
      : (json.output ?? [])
          .flatMap((item: any) => item.content ?? [])
          .map((content: any) => content.text ?? "")
          .join("\n")
          .trim()

    return {
      reply: text || "AI belum memberi jawaban. Coba tanya ulang dengan detail sedikit.",
      responseId: json.id ?? null,
      provider: "openai",
      model: openAiModel,
      configured: true,
    }
  } finally {
    clearTimeout(timeout)
  }
}

export async function POST(req: NextRequest) {
  try {
    if (!adminAuth || !adminDb) return NextResponse.json({ error: "Server not configured" }, { status: 500 })

    const token = req.headers.get("authorization")?.replace("Bearer ", "")
    if (!token) return NextResponse.json({ error: "Unauthorized" }, { status: 401 })

    const decoded = await adminAuth.verifyIdToken(token)
    const body = await req.json().catch(() => ({}))
    const message = String(body.message ?? "").trim()
    if (!message) return NextResponse.json({ error: "Message is required" }, { status: 400 })
    if (message.length > maxMessageLength) return NextResponse.json({ error: "Message is too long" }, { status: 400 })

    const history = sanitizeHistory(body.history)
    const summary = await getFinanceSummary(decoded.uid)
    const response = await createOpenAiResponse(message, history, summary)

    return NextResponse.json({
      reply: response.reply,
      responseId: response.responseId,
      provider: response.provider,
      model: response.model,
      configured: response.configured,
      summary: { scope: summary.scope, period: summary.period },
    })
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error"
    return NextResponse.json({ error: message }, { status: 500 })
  }
}

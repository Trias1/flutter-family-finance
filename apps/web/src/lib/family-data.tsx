"use client"

import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from "react"
import {
  collection,
  doc,
  onSnapshot,
  query,
  where,
  type DocumentData,
  type QueryDocumentSnapshot,
  type Timestamp,
} from "firebase/firestore"

import { db } from "@/lib/firebase"

export type Tx = {
  id: string
  kind: "income" | "expense"
  amount: number
  category: string
  note: string
  date: Date
  userId: string
}

export type Budget = {
  id: string
  month: string
  category: string
  budgetAmount: number
  usedAmount: number
}

export type Saving = {
  id: string
  name: string
  category: string
  targetAmount: number
  currentAmount: number
  targetDate: Date | null
  goldGrams: number | null
}

export type Debt = {
  id: string
  type: "hutang" | "piutang"
  personName: string
  description: string
  amount: number
  remainingAmount: number
  dueDate: Date | null
  status: "active" | "paid" | "cancelled"
}

export type Bill = {
  id: string
  name: string
  amount: number
  dueDate: Date | null
  status: string
  repeatType: string
}

export type Member = { id: string; name: string }

type Collections = {
  incomes: Tx[]
  expenses: Tx[]
  budgets: Budget[]
  savings: Saving[]
  debts: Debt[]
  bills: Bill[]
  members: Member[]
}

type CollectionKey = keyof Collections

export type SyncState = "connecting" | "synced" | "offline"

export type FamilyData = Collections & {
  ready: boolean
  scope: "family" | "personal"
  familyName: string | null
  sync: SyncState
  lastSyncedAt: Date | null
  failed: CollectionKey[]
  memberName: (userId: string) => string
}

const empty: Collections = { incomes: [], expenses: [], budgets: [], savings: [], debts: [], bills: [], members: [] }

const num = (value: unknown) => (typeof value === "number" && Number.isFinite(value) ? value : Number(value) || 0)
const str = (value: unknown) => (typeof value === "string" ? value : "")
const date = (value: unknown) => {
  const ts = value as Timestamp | null | undefined
  return ts && typeof ts.toDate === "function" ? ts.toDate() : null
}

type Doc = QueryDocumentSnapshot<DocumentData>

const parsers: { [K in CollectionKey]: (d: Doc) => Collections[K][number] } = {
  incomes: (d) => parseTx(d, "income"),
  expenses: (d) => parseTx(d, "expense"),
  budgets: (d) => {
    const x = d.data()
    return { id: d.id, month: str(x.month), category: str(x.category), budgetAmount: num(x.budgetAmount), usedAmount: num(x.usedAmount) }
  },
  savings: (d) => {
    const x = d.data()
    return {
      id: d.id,
      name: str(x.name),
      category: str(x.category),
      targetAmount: num(x.targetAmount),
      currentAmount: num(x.currentAmount),
      targetDate: date(x.targetDate),
      goldGrams: typeof x.goldGrams === "number" ? x.goldGrams : null,
    }
  },
  debts: (d) => {
    const x = d.data()
    return {
      id: d.id,
      type: x.type === "piutang" ? "piutang" : "hutang",
      personName: str(x.personName),
      description: str(x.description),
      amount: num(x.amount),
      remainingAmount: num(x.remainingAmount ?? x.amount),
      dueDate: date(x.dueDate),
      status: x.status === "paid" ? "paid" : x.status === "cancelled" ? "cancelled" : "active",
    }
  },
  bills: (d) => {
    const x = d.data()
    return { id: d.id, name: str(x.name), amount: num(x.amount), dueDate: date(x.dueDate), status: str(x.status), repeatType: str(x.repeatType) }
  },
  members: (d) => {
    const x = d.data()
    return { id: d.id, name: str(x.name) || str(x.email).split("@")[0] || "Anggota" }
  },
}

function parseTx(d: Doc, kind: Tx["kind"]): Tx {
  const x = d.data()
  return {
    id: d.id,
    kind,
    amount: num(x.amount),
    category: str(x.category) || "Lainnya",
    note: str(x.note),
    date: date(x.date) ?? date(x.createdAt) ?? new Date(0),
    userId: str(x.userId),
  }
}

const FamilyDataContext = createContext<FamilyData | null>(null)

export function useFamilyData() {
  const value = useContext(FamilyDataContext)
  if (!value) throw new Error("useFamilyData must be used inside FamilyDataProvider")
  return value
}

type Scope = { id: string; kind: "family" | "personal" } | null

/**
 * Live view of the signed-in user's finance data. Data recorded on Android
 * shows up within seconds; Firestore's local cache makes reloads instant.
 * Without a family, the Android app stores data under the user's own uid,
 * so that is used as the scope.
 */
export function FamilyDataProvider({ uid, children }: { uid: string; children: ReactNode }) {
  const [scope, setScope] = useState<Scope>(null)
  const [familyName, setFamilyName] = useState<string | null>(null)
  const [data, setData] = useState<Collections>(empty)
  const [loaded, setLoaded] = useState<Set<CollectionKey>>(new Set())
  const [cached, setCached] = useState<Set<CollectionKey>>(new Set())
  const [failed, setFailed] = useState<CollectionKey[]>([])
  const [lastSyncedAt, setLastSyncedAt] = useState<Date | null>(null)
  const [online, setOnline] = useState(true)
  const [isDemo, setIsDemo] = useState(false)

  useEffect(() => {
    const update = () => setOnline(navigator.onLine)
    const first = window.setTimeout(update, 0)
    window.addEventListener("online", update)
    window.addEventListener("offline", update)
    return () => {
      window.clearTimeout(first)
      window.removeEventListener("online", update)
      window.removeEventListener("offline", update)
    }
  }, [])

  // The user's own doc decides the scope; follow it so joining or leaving a
  // family on Android switches the web view too.
  useEffect(() => {
    return onSnapshot(
      doc(db, "users", uid),
      (snap) => {
        const familyId = str(snap.data()?.familyId)
        setScope((prev) => {
          const next: Scope = familyId ? { id: familyId, kind: "family" } : { id: uid, kind: "personal" }
          return prev && prev.id === next.id && prev.kind === next.kind ? prev : next
        })
      },
      () => setScope({ id: uid, kind: "personal" }),
    )
  }, [uid])

  useEffect(() => {
    if (!scope) return

    if (process.env.NODE_ENV === "development" && new URLSearchParams(window.location.search).get("demo") === "1") {
      let cancelled = false
      void import("@/lib/demo-data").then(({ buildDemoData }) => {
        if (cancelled) return
        setData(buildDemoData())
        setFamilyName("Keluarga Contoh")
        setIsDemo(true)
        setLoaded(new Set<CollectionKey>(["incomes", "expenses", "budgets", "savings", "debts", "bills", "members"]))
        setLastSyncedAt(new Date())
      })
      return () => {
        cancelled = true
      }
    }

    const keys: CollectionKey[] = ["incomes", "expenses", "budgets", "savings", "debts", "bills"]
    if (scope.kind === "family") keys.push("members")

    const unsubs = keys.map((key) => {
      const source = key === "members" ? "users" : key
      return onSnapshot(
        query(collection(db, source), where("familyId", "==", scope.id)),
        { includeMetadataChanges: true },
        (snap) => {
          const parse = parsers[key] as (d: Doc) => Collections[typeof key][number]
          setData((prev) => ({ ...prev, [key]: snap.docs.map((d) => parse(d)) }))
          setLoaded((prev) => (prev.has(key) ? prev : new Set(prev).add(key)))
          setCached((prev) => {
            const next = new Set(prev)
            if (snap.metadata.fromCache) next.add(key)
            else next.delete(key)
            return next
          })
          if (!snap.metadata.fromCache) setLastSyncedAt(new Date())
          setFailed((prev) => (prev.includes(key) ? prev.filter((k) => k !== key) : prev))
        },
        (error) => {
          console.warn(`[family-data] ${key}:`, error.code)
          setLoaded((prev) => new Set(prev).add(key))
          setFailed((prev) => (prev.includes(key) ? prev : [...prev, key]))
        },
      )
    })

    const unsubFamily =
      scope.kind === "family"
        ? onSnapshot(
            doc(db, "families", scope.id),
            (snap) => setFamilyName(str(snap.data()?.name) || null),
            () => setFamilyName(null),
          )
        : () => {}

    return () => {
      unsubs.forEach((unsub) => unsub())
      unsubFamily()
      setData(empty)
      setLoaded(new Set())
      setCached(new Set())
      setFailed([])
      setFamilyName(null)
    }
  }, [scope])

  const value = useMemo<FamilyData>(() => {
    const kind = isDemo ? "family" : scope?.kind ?? "personal"
    const expected = scope?.kind === "family" || isDemo ? 7 : 6
    const names = new Map(data.members.map((m) => [m.id, m.name]))
    return {
      ...data,
      ready: scope !== null && loaded.size >= expected,
      scope: kind,
      familyName,
      sync: !online ? "offline" : cached.size > 0 || loaded.size < expected ? "connecting" : "synced",
      lastSyncedAt,
      failed,
      memberName: (userId) => names.get(userId) ?? "",
    }
  }, [data, scope, loaded, cached, failed, familyName, lastSyncedAt, online, isDemo])

  return <FamilyDataContext.Provider value={value}>{children}</FamilyDataContext.Provider>
}

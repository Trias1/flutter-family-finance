"use client"

import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from "react"
import {
  collection,
  doc,
  onSnapshot,
  orderBy,
  query,
  Timestamp,
  where,
  type DocumentData,
  type Query,
  type QueryDocumentSnapshot,
} from "firebase/firestore"
import { useTranslations } from "next-intl"

import { db } from "@/lib/firebase"
import { setDisplayCurrency, startOfMonth } from "@/lib/money"

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
  /** Effective limit: the month's budget plus last month's rollover. */
  budgetAmount: number
  usedAmount: number
  rolloverAmount: number
}

export type Saving = {
  id: string
  name: string
  category: string
  targetAmount: number
  currentAmount: number
  targetDate: Date | null
  createdAt: Date | null
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

export type CollectionKey = keyof Collections

export type SyncState = "connecting" | "synced" | "offline"

export type FamilyData = Collections & {
  ready: boolean
  scope: "family" | "personal"
  familyName: string | null
  /** Uid of the family's creator (family mode only). */
  familyOwnerId: string | null
  /** Name on the signed-in user's own profile doc. */
  profileName: string | null
  /** ISO code shown for amounts, e.g. "IDR". */
  currency: string
  sync: SyncState
  lastSyncedAt: Date | null
  failed: CollectionKey[]
  memberName: (userId: string) => string
  /** Incomes and expenses are loaded from this month onwards. */
  loadedFrom: Date
  /** True while an older range requested with `loadOlder` is still arriving. */
  loadingOlder: boolean
  /** Makes sure records from `monthsBack` months ago onwards are loaded. */
  loadOlder: (monthsBack: number) => void
  /** Drops every listener and subscribes again, e.g. after a failed load. */
  retry: () => void
}

// Incomes and expenses are the only collections that grow without bound, so
// only the last 13 months (this month plus 12) are kept live by default.
export const WINDOW_MONTHS = 12

const emptyRest = { budgets: [], savings: [], debts: [], bills: [], members: [] }
type Rest = Omit<Collections, "incomes" | "expenses">
type RestKey = keyof Rest

const num = (value: unknown) => (typeof value === "number" && Number.isFinite(value) ? value : Number(value) || 0)
const str = (value: unknown) => (typeof value === "string" ? value : "")
const date = (value: unknown) => {
  const ts = value as Timestamp | null | undefined
  return ts && typeof ts.toDate === "function" ? ts.toDate() : null
}

type Doc = QueryDocumentSnapshot<DocumentData>

// Names and categories may be empty here; the provider fills them in the
// viewer's language (see `localized` below).
const parsers: { [K in RestKey]: (d: Doc) => Rest[K][number] } = {
  budgets: (d) => {
    const x = d.data()
    return { id: d.id, month: str(x.month), category: str(x.category), budgetAmount: num(x.budgetAmount) + num(x.rolloverAmount), usedAmount: num(x.usedAmount), rolloverAmount: num(x.rolloverAmount) }
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
      createdAt: date(x.createdAt),
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
    return { id: d.id, name: str(x.name) || str(x.email).split("@")[0] }
  },
}

/** A record without any usable date belongs to no month, so it is skipped rather than shown as January 1970. */
function parseTx(d: Doc, kind: Tx["kind"]): Tx | null {
  const x = d.data()
  const when = date(x.date) ?? date(x.createdAt)
  if (!when) return null
  return { id: d.id, kind, amount: num(x.amount), category: str(x.category), note: str(x.note), date: when, userId: str(x.userId) }
}

const FamilyDataContext = createContext<FamilyData | null>(null)

export function useFamilyData() {
  const value = useContext(FamilyDataContext)
  if (!value) throw new Error("useFamilyData must be used inside FamilyDataProvider")
  return value
}

type Scope = { id: string; kind: "family" | "personal" } | null

/** One date range of incomes and expenses; `to` is null for the live, open-ended newest range. */
type Chunk = { from: number; to: number | null }
const chunkKey = (c: Chunk) => `${c.from}-${c.to ?? "now"}`

/** Fills an empty category in, keeping the array as is when nothing is missing. */
function withCategory(items: Tx[], fallback: string) {
  return items.some((x) => !x.category) ? items.map((x) => (x.category ? x : { ...x, category: fallback })) : items
}

/**
 * Live view of the signed-in user's finance data. Data recorded on Android
 * shows up within seconds; Firestore's local cache makes reloads instant.
 * Without a family, the Android app stores data under the user's own uid,
 * so that is used as the scope.
 */
export function FamilyDataProvider({ uid, children }: { uid: string; children: ReactNode }) {
  const tc = useTranslations("dash.common")
  const [scope, setScope] = useState<Scope>(null)
  const [familyName, setFamilyName] = useState<string | null>(null)
  const [familyOwnerId, setFamilyOwnerId] = useState<string | null>(null)
  const [profileName, setProfileName] = useState<string | null>(null)
  const [userCurrency, setUserCurrency] = useState<string | null>(null)
  const [familyCurrency, setFamilyCurrency] = useState<string | null>(null)
  const [rest, setRest] = useState<Rest>(emptyRest)
  const [txByChunk, setTxByChunk] = useState<Record<string, { incomes: Tx[]; expenses: Tx[] }>>({})
  const [loaded, setLoaded] = useState<Set<string>>(new Set())
  const [cached, setCached] = useState<Set<string>>(new Set())
  const [failed, setFailed] = useState<CollectionKey[]>([])
  const [lastSyncedAt, setLastSyncedAt] = useState<Date | null>(null)
  const [online, setOnline] = useState(true)
  const [isDemo, setIsDemo] = useState(false)
  const [attempt, setAttempt] = useState(0)
  // Newest first: the first chunk is live and open-ended, older ones are added by loadOlder.
  const [chunks, setChunks] = useState<Chunk[]>(() => [{ from: startOfMonth(new Date(), -WINDOW_MONTHS).getTime(), to: null }])
  const txUnsubs = useRef(new Map<string, () => void>())

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
        setUserCurrency(str(snap.data()?.currency) || null)
        setProfileName(str(snap.data()?.name) || null)
        setScope((prev) => {
          const next: Scope = familyId ? { id: familyId, kind: "family" } : { id: uid, kind: "personal" }
          return prev && prev.id === next.id && prev.kind === next.kind ? prev : next
        })
      },
      () => setScope({ id: uid, kind: "personal" }),
    )
  }, [uid])

  /**
   * Subscribes with metadata changes so the cached -> synced switch is seen
   * (the indicator needs it), but only re-parses when documents changed.
   */
  const listen = useCallback((q: Query, key: string, onDocs: (docs: Doc[]) => void, onFail: (code: string) => void) => {
    let first = true
    return onSnapshot(
      q,
      { includeMetadataChanges: true },
      (snap) => {
        if (first || snap.docChanges().length > 0) onDocs(snap.docs)
        first = false
        setLoaded((prev) => (prev.has(key) ? prev : new Set(prev).add(key)))
        const fromCache = snap.metadata.fromCache
        setCached((prev) => {
          if (prev.has(key) === fromCache) return prev
          const next = new Set(prev)
          if (fromCache) next.add(key)
          else next.delete(key)
          return next
        })
        if (!fromCache) setLastSyncedAt(new Date())
      },
      (error) => {
        onFail(error.code)
        setLoaded((prev) => (prev.has(key) ? prev : new Set(prev).add(key)))
      },
    )
  }, [])

  const markOk = useCallback((key: CollectionKey) => setFailed((prev) => (prev.includes(key) ? prev.filter((k) => k !== key) : prev)), [])
  const markFailed = useCallback((key: CollectionKey, code: string) => {
    console.warn(`[family-data] ${key}:`, code)
    setFailed((prev) => (prev.includes(key) ? prev : [...prev, key]))
  }, [])

  // Everything except incomes/expenses: small collections, loaded whole.
  useEffect(() => {
    if (!scope) return

    if (process.env.NODE_ENV === "development" && new URLSearchParams(window.location.search).get("demo") === "1") {
      let cancelled = false
      void import("@/lib/demo-data").then(({ buildDemoData }) => {
        if (cancelled) return
        const demo = buildDemoData()
        setRest({ budgets: demo.budgets, savings: demo.savings, debts: demo.debts, bills: demo.bills, members: demo.members })
        setTxByChunk({ demo: { incomes: demo.incomes, expenses: demo.expenses } })
        setFamilyName("Keluarga Contoh")
        setIsDemo(true)
        setLastSyncedAt(new Date())
      })
      return () => {
        cancelled = true
      }
    }

    const keys: RestKey[] = ["budgets", "savings", "debts", "bills"]
    if (scope.kind === "family") keys.push("members")

    const unsubs = keys.map((key) =>
      listen(
        query(collection(db, key === "members" ? "users" : key), where("familyId", "==", scope.id)),
        key,
        (docs) => {
          const parse = parsers[key] as (d: Doc) => Rest[typeof key][number]
          setRest((prev) => ({ ...prev, [key]: docs.map((d) => parse(d)) }))
          markOk(key)
        },
        (code) => markFailed(key, code),
      ),
    )

    const unsubFamily =
      scope.kind === "family"
        ? onSnapshot(
            doc(db, "families", scope.id),
            (snap) => {
              setFamilyName(str(snap.data()?.name) || null)
              setFamilyCurrency(str(snap.data()?.currency) || null)
              setFamilyOwnerId(str(snap.data()?.createdBy) || null)
            },
            () => setFamilyName(null),
          )
        : () => {}

    return () => {
      unsubs.forEach((unsub) => unsub())
      unsubFamily()
      setRest(emptyRest)
      setLoaded(new Set())
      setCached(new Set())
      setFailed([])
      setFamilyName(null)
      setFamilyCurrency(null)
      setFamilyOwnerId(null)
    }
  }, [scope, attempt, listen, markOk, markFailed])

  // Incomes/expenses: one listener pair per date range. Extending the window
  // only adds listeners for the new, older range, so nothing is read twice.
  useEffect(() => {
    if (!scope || isDemo) return
    const active = txUnsubs.current
    for (const chunk of chunks) {
      const id = chunkKey(chunk)
      if (active.has(id)) continue
      const unsubs = (["incomes", "expenses"] as const).map((key) => {
        const constraints = [
          where("familyId", "==", scope.id),
          where("date", ">=", Timestamp.fromMillis(chunk.from)),
          ...(chunk.to === null ? [] : [where("date", "<", Timestamp.fromMillis(chunk.to))]),
          // Matches the existing (familyId asc, date desc) composite indexes.
          orderBy("date", "desc"),
        ]
        return listen(
          query(collection(db, key), ...constraints),
          `${key}:${id}`,
          (docs) => {
            const kind = key === "incomes" ? "income" : "expense"
            const parsed = docs.map((d) => parseTx(d, kind)).filter((tx): tx is Tx => tx !== null)
            setTxByChunk((prev) => ({ ...prev, [id]: { incomes: prev[id]?.incomes ?? [], expenses: prev[id]?.expenses ?? [], [key]: parsed } }))
            markOk(key)
          },
          (code) => markFailed(key, code),
        )
      })
      active.set(id, () => unsubs.forEach((u) => u()))
    }
  }, [scope, chunks, attempt, isDemo, listen, markOk, markFailed])

  // A new scope (or a retry) drops every range listener; the effect above
  // then subscribes again to the same ranges.
  useEffect(() => {
    const active = txUnsubs.current
    return () => {
      active.forEach((unsub) => unsub())
      active.clear()
      setTxByChunk({})
    }
  }, [scope, attempt])

  const loadOlder = useCallback((monthsBack: number) => {
    const from = startOfMonth(new Date(), -Math.max(0, Math.ceil(monthsBack))).getTime()
    setChunks((prev) => {
      const oldest = prev[prev.length - 1].from
      return from < oldest ? [...prev, { from, to: oldest }] : prev
    })
  }, [])

  const retry = useCallback(() => setAttempt((n) => n + 1), [])

  const other = tc("otherCategory")
  const memberFallback = tc("member")
  const localized = useMemo(() => {
    const parts = Object.values(txByChunk)
    return {
      incomes: withCategory(parts.flatMap((p) => p.incomes), other),
      expenses: withCategory(parts.flatMap((p) => p.expenses), other),
      members: rest.members.map((m) => (m.name ? m : { ...m, name: memberFallback })),
    }
  }, [txByChunk, rest.members, other, memberFallback])

  const value = useMemo<FamilyData>(() => {
    const kind = isDemo ? "family" : scope?.kind ?? "personal"
    const restKeys = kind === "family" ? 5 : 4
    const loadedRest = Array.from(loaded).filter((k) => !k.includes(":")).length
    const newest = chunkKey(chunks[0])
    const txReady = isDemo || (loaded.has(`incomes:${newest}`) && loaded.has(`expenses:${newest}`))
    const allReady = isDemo || (loadedRest >= restKeys && txReady)
    const loadingOlder = !isDemo && chunks.slice(1).some((c) => !loaded.has(`incomes:${chunkKey(c)}`) || !loaded.has(`expenses:${chunkKey(c)}`))
    const names = new Map(localized.members.map((m) => [m.id, m.name]))
    // Set before children render so every amount uses the same currency.
    const currency = (kind === "family" ? familyCurrency : userCurrency) ?? "IDR"
    setDisplayCurrency(currency)
    return {
      ...rest,
      ...localized,
      ready: scope !== null && (isDemo ? lastSyncedAt !== null : allReady),
      scope: kind,
      familyName,
      familyOwnerId,
      profileName,
      sync: !online ? "offline" : cached.size > 0 || !allReady ? "connecting" : "synced",
      lastSyncedAt,
      failed,
      memberName: (userId) => names.get(userId) ?? "",
      currency,
      // Demo data covers six months only, but nothing older exists there.
      loadedFrom: isDemo ? new Date(0) : new Date(chunks[chunks.length - 1].from),
      loadingOlder,
      loadOlder,
      retry,
    }
  }, [rest, localized, chunks, scope, loaded, cached, failed, familyName, familyOwnerId, profileName, lastSyncedAt, online, isDemo, userCurrency, familyCurrency, loadOlder, retry])

  return <FamilyDataContext.Provider value={value}>{children}</FamilyDataContext.Provider>
}

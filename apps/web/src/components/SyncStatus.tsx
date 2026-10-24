"use client"

import { useEffect, useState } from "react"
import { useTranslations } from "next-intl"

import { useFamilyData } from "@/lib/family-data"

function useNow(intervalMs: number) {
  const [now, setNow] = useState(() => Date.now())
  useEffect(() => {
    const id = window.setInterval(() => setNow(Date.now()), intervalMs)
    return () => window.clearInterval(id)
  }, [intervalMs])
  return now
}

export default function SyncStatus() {
  const t = useTranslations("dash.sync")
  const { sync, lastSyncedAt, failed } = useFamilyData()
  const now = useNow(30_000)

  let label: string
  let color: string
  if (sync === "offline") {
    label = t("offline")
    color = "var(--text-muted)"
  } else if (sync === "connecting") {
    label = t("connecting")
    color = "var(--warning)"
  } else {
    const minutes = lastSyncedAt ? Math.floor((now - lastSyncedAt.getTime()) / 60_000) : 0
    label = minutes < 1 ? t("syncedNow") : t("syncedAgo", { minutes })
    color = "var(--income)"
  }

  return (
    <div className="flex items-center gap-2 text-xs" style={{ color: "var(--text-secondary)" }} aria-live="polite" title={failed.length ? t("partial") : undefined}>
      <span className="inline-flex h-2 w-2 rounded-full" style={{ backgroundColor: color }} />
      <span>{label}</span>
      {failed.length > 0 && <span style={{ color: "var(--warning)" }}>· {t("partial")}</span>}
    </div>
  )
}

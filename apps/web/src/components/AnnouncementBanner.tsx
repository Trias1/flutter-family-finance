"use client"

import { useEffect, useState } from "react"
import { doc, onSnapshot } from "firebase/firestore"
import { Info, Wrench } from "lucide-react"
import { useLocale } from "next-intl"

import { db } from "@/lib/firebase"

type Announcement = { messageId: string; messageEn: string; tone: "info" | "maintenance" }

/** Banner set from the admin panel (app_config/announcement); also shown in the Android app. */
export default function AnnouncementBanner() {
  const locale = useLocale()
  const [current, setCurrent] = useState<Announcement | null>(null)

  useEffect(() => {
    return onSnapshot(
      doc(db, "app_config", "announcement"),
      (snap) => {
        const d = snap.data()
        setCurrent(
          d?.active === true
            ? {
                messageId: typeof d.messageId === "string" ? d.messageId : "",
                messageEn: typeof d.messageEn === "string" ? d.messageEn : "",
                tone: d.tone === "maintenance" ? "maintenance" : "info",
              }
            : null,
        )
      },
      () => setCurrent(null),
    )
  }, [])

  const text = current ? (locale === "id" ? current.messageId : current.messageEn) || current.messageId || current.messageEn : ""
  if (!current || !text) return null

  const maintenance = current.tone === "maintenance"
  const Icon = maintenance ? Wrench : Info
  return (
    <div
      role="status"
      className="mb-5 flex items-start gap-3 rounded-lg border px-4 py-3 text-sm"
      style={{
        borderColor: maintenance ? "var(--warning)" : "var(--border)",
        backgroundColor: "var(--bg-card)",
        color: "var(--text-primary)",
      }}
    >
      <Icon size={16} className="mt-0.5 shrink-0" style={{ color: maintenance ? "var(--warning)" : "var(--primary)" }} aria-hidden="true" />
      <p className="leading-6">{text}</p>
    </div>
  )
}

"use client"

import { useEffect, useId, useRef, type ReactNode } from "react"

/**
 * Small modal for confirming admin actions. Escape or the backdrop closes it
 * (unless busy); focus moves into it on open and back to the opener on close.
 */
export default function AdminDialog({ title, onClose, busy = false, children }: { title: string; onClose: () => void; busy?: boolean; children: ReactNode }) {
  const titleId = useId()
  const panel = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const opener = document.activeElement as HTMLElement | null
    const first = panel.current?.querySelector<HTMLElement>("input, button, select, textarea")
    first?.focus()
    return () => opener?.focus()
  }, [])

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape" && !busy) onClose()
    }
    document.addEventListener("keydown", onKey)
    return () => document.removeEventListener("keydown", onKey)
  }, [busy, onClose])

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4" style={{ backgroundColor: "rgb(0 0 0 / 0.4)" }} onMouseDown={(e) => e.target === e.currentTarget && !busy && onClose()}>
      <div ref={panel} role="dialog" aria-modal="true" aria-labelledby={titleId} className="w-full max-w-md rounded-lg border" style={{ backgroundColor: "var(--bg-card)", borderColor: "var(--border)" }}>
        <h2 id={titleId} className="border-b px-5 py-3.5 text-sm font-semibold" style={{ borderColor: "var(--border)", color: "var(--text-primary)" }}>{title}</h2>
        <div className="space-y-4 p-5">{children}</div>
      </div>
    </div>
  )
}

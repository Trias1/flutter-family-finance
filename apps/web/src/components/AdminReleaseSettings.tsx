"use client"

import { useState, type FormEvent } from "react"
import { useTranslations } from "next-intl"

import { Section } from "@/components/ui"
import type { AdminAnnouncement } from "@/lib/admin-types"

type Notice = (tone: "ok" | "error", text: string) => void

// Both forms start from the server values; the admin page re-mounts them
// (via `key`) when those values change after a save.

/**
 * Force update + release notes shown in the Android update dialog. The
 * version itself is published by the release script (or the publish button).
 */
export function AndroidReleaseSettings({
  initial,
  onSave,
  notify,
  apiError,
}: {
  initial: { forceUpdate: boolean; releaseNotes: string }
  onSave: (body: { forceUpdate: boolean; releaseNotes: string }) => Promise<void>
  notify: Notice
  apiError: (err: unknown) => string
}) {
  const t = useTranslations("admin.release")
  const [forceUpdate, setForceUpdate] = useState(initial.forceUpdate)
  const [notes, setNotes] = useState(initial.releaseNotes)
  const [busy, setBusy] = useState(false)


  const dirty = forceUpdate !== initial.forceUpdate || notes.trim() !== initial.releaseNotes

  const submit = async (e: FormEvent) => {
    e.preventDefault()
    if (forceUpdate && !initial.forceUpdate && !window.confirm(t("confirmForce"))) return
    setBusy(true)
    try {
      await onSave({ forceUpdate, releaseNotes: notes.trim() })
      notify("ok", t("saved"))
    } catch (err) {
      notify("error", apiError(err))
    } finally {
      setBusy(false)
    }
  }

  return (
    <Section title={t("title")} aside={t("aside")}>
      <form onSubmit={submit} className="space-y-4">
        <label className="flex items-start gap-3">
          <input
            type="checkbox"
            checked={forceUpdate}
            onChange={(e) => setForceUpdate(e.target.checked)}
            className="mt-1 h-4 w-4"
          />
          <span>
            <span className="block text-sm font-medium" style={{ color: "var(--text-primary)" }}>{t("forceLabel")}</span>
            <span className="block text-xs leading-5" style={{ color: "var(--text-muted)" }}>{t("forceHint")}</span>
          </span>
        </label>
        <div>
          <label htmlFor="release-notes" className="mb-1 block text-xs font-medium" style={{ color: "var(--text-secondary)" }}>{t("notesLabel")}</label>
          <textarea
            id="release-notes"
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            maxLength={500}
            rows={3}
            className="field w-full resize-y py-2"
            placeholder={t("notesPlaceholder")}
          />
          <p className="mt-1 text-right text-xs tabular-nums" style={{ color: "var(--text-muted)" }}>{notes.length}/500</p>
        </div>
        <div className="flex justify-end">
          <button type="submit" disabled={busy || !dirty} className="auth-btn-primary !h-9 !w-auto px-4">
            {busy ? t("saving") : t("save")}
          </button>
        </div>
      </form>
    </Section>
  )
}

/** Banner shown in the Android app and on the web dashboard. */
export function AnnouncementSettings({
  initial,
  onSave,
  notify,
  apiError,
}: {
  initial: AdminAnnouncement
  onSave: (body: AdminAnnouncement) => Promise<void>
  notify: Notice
  apiError: (err: unknown) => string
}) {
  const t = useTranslations("admin.announcement")
  const [draft, setDraft] = useState<AdminAnnouncement>(initial)
  const [busy, setBusy] = useState(false)


  const save = async (active: boolean) => {
    setBusy(true)
    try {
      await onSave({ ...draft, active })
      notify("ok", active ? t("shown") : t("hidden"))
    } catch (err) {
      notify("error", apiError(err))
    } finally {
      setBusy(false)
    }
  }

  const hasText = draft.messageId.trim() !== "" || draft.messageEn.trim() !== ""

  return (
    <Section title={t("title")} aside={initial.active ? t("liveNow") : t("off")}>
      <div className="space-y-4">
        <div className="flex flex-wrap gap-2" role="radiogroup" aria-label={t("toneLabel")}>
          {(["info", "maintenance"] as const).map((tone) => (
            <button
              key={tone}
              type="button"
              role="radio"
              aria-checked={draft.tone === tone}
              onClick={() => setDraft((d) => ({ ...d, tone }))}
              className={draft.tone === tone ? "auth-btn-primary !h-8 !w-auto px-3 text-xs" : "auth-btn-secondary !h-8 !w-auto px-3 text-xs"}
            >
              {t(`tone.${tone}`)}
            </button>
          ))}
        </div>
        <div className="grid gap-3 md:grid-cols-2">
          <div>
            <label htmlFor="ann-id" className="mb-1 block text-xs font-medium" style={{ color: "var(--text-secondary)" }}>{t("messageId")}</label>
            <textarea id="ann-id" rows={2} maxLength={280} value={draft.messageId} onChange={(e) => setDraft((d) => ({ ...d, messageId: e.target.value }))} className="field w-full resize-y py-2" placeholder={t("placeholderId")} />
          </div>
          <div>
            <label htmlFor="ann-en" className="mb-1 block text-xs font-medium" style={{ color: "var(--text-secondary)" }}>{t("messageEn")}</label>
            <textarea id="ann-en" rows={2} maxLength={280} value={draft.messageEn} onChange={(e) => setDraft((d) => ({ ...d, messageEn: e.target.value }))} className="field w-full resize-y py-2" placeholder={t("placeholderEn")} />
          </div>
        </div>
        <p className="text-xs leading-5" style={{ color: "var(--text-muted)" }}>{t("hint")}</p>
        <div className="flex flex-wrap justify-end gap-2">
          {initial.active && (
            <button type="button" disabled={busy} onClick={() => save(false)} className="auth-btn-secondary !h-9 !w-auto px-4">{t("hide")}</button>
          )}
          <button type="button" disabled={busy || !hasText} onClick={() => save(true)} className="auth-btn-primary !h-9 !w-auto px-4">
            {busy ? t("saving") : initial.active ? t("update") : t("show")}
          </button>
        </div>
      </div>
    </Section>
  )
}

"use client"

import { useTranslations } from "next-intl"

export default function LocaleError({ reset }: { error: Error; reset: () => void }) {
  const t = useTranslations("errorPage")
  return (
    <main className="flex min-h-screen flex-col items-center justify-center px-6 text-center" style={{ backgroundColor: "var(--bg)", color: "var(--text-primary)" }}>
      <p className="text-sm font-medium" style={{ color: "var(--expense)" }}>{t("label")}</p>
      <h1 className="mt-2 text-2xl font-semibold">{t("title")}</h1>
      <p className="mt-2 max-w-md text-sm" style={{ color: "var(--text-secondary)" }}>{t("desc")}</p>
      <button type="button" onClick={reset} className="auth-btn-primary mt-6 !w-auto px-5">{t("retry")}</button>
    </main>
  )
}

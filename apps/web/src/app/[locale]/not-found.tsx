import { getTranslations } from "next-intl/server"

import PublicTheme from "@/components/public/PublicTheme"
import { Link } from "@/lib/i18n"

export default async function LocaleNotFound() {
  const t = await getTranslations("notFound")
  return (
    <main className="flex min-h-screen flex-col items-center justify-center px-6 text-center" style={{ backgroundColor: "var(--bg)", color: "var(--text-primary)" }}>
      <PublicTheme />
      <p className="text-sm font-medium tabular-nums" style={{ color: "var(--text-muted)" }}>404</p>
      <h1 className="mt-2 text-2xl font-semibold">{t("title")}</h1>
      <p className="mt-2 max-w-md text-sm" style={{ color: "var(--text-secondary)" }}>{t("desc")}</p>
      <Link href="/" className="auth-btn-primary mt-6 !w-auto px-5">{t("home")}</Link>
    </main>
  )
}

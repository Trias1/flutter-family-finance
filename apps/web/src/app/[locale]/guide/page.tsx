import { statSync } from "node:fs"
import { join } from "node:path"

import PublicNavbar from "@/components/public/PublicNavbar"
import { Link } from "@/lib/i18n"
import { getTranslations } from "next-intl/server"

const steps = [
  { n: 1, details: 3 },
  { n: 2, details: 4 },
  { n: 3, details: 4 },
  { n: 4, details: 4 },
  { n: 5, details: 4 },
  { n: 6, details: 4 },
  { n: 7, details: 4 },
  { n: 8, details: 4 },
]

function apkSizeLabel() {
  try {
    const bytes = statSync(join(process.cwd(), "public", "FamilyFinance.apk")).size
    return `${(bytes / 1024 / 1024).toFixed(1)} MB`
  } catch {
    return null
  }
}

export default async function GuidePage() {
  const t = await getTranslations()
  const apkSize = apkSizeLabel()

  return (
    <div className="min-h-screen" style={{ backgroundColor: "var(--bg)" }}>
      <PublicNavbar />

      <header className="mx-auto max-w-3xl px-5 pb-10 pt-28 sm:px-8 lg:pt-36">
        <p className="text-xs font-semibold uppercase tracking-[0.14em]" style={{ color: "var(--primary)" }}>{t("guide.badge")}</p>
        <h1 className="mt-4 text-3xl font-bold leading-tight tracking-tight sm:text-4xl" style={{ color: "var(--text-primary)" }}>
          {t("guide.title")}
        </h1>
        <p className="mt-4 text-base leading-7" style={{ color: "var(--text-secondary)" }}>{t("guide.desc")}</p>
      </header>

      <ol className="mx-auto max-w-3xl border-t px-5 sm:px-8" style={{ borderColor: "var(--border)" }}>
        {steps.map(({ n, details }) => (
          <li key={n} className="grid gap-x-6 gap-y-2 border-b py-8 sm:grid-cols-[48px_1fr]" style={{ borderColor: "var(--border)" }}>
            <span className="font-mono text-sm tabular-nums" style={{ color: "var(--text-muted)" }}>{String(n).padStart(2, "0")}</span>
            <div>
              <h2 className="text-lg font-semibold" style={{ color: "var(--text-primary)" }}>{t(`guide.step${n}Title`)}</h2>
              <p className="mt-2 text-sm leading-6" style={{ color: "var(--text-secondary)" }}>{t(`guide.step${n}Desc`)}</p>
              <ul className="mt-3 list-disc space-y-1.5 pl-5 text-sm leading-6" style={{ color: "var(--text-secondary)" }}>
                {Array.from({ length: details }, (_, i) => (
                  <li key={i}>{t(`guide.step${n}Detail${i + 1}`)}</li>
                ))}
              </ul>
            </div>
          </li>
        ))}
      </ol>

      <section id="download" className="mx-auto max-w-3xl px-5 py-14 sm:px-8">
        <h2 className="text-2xl font-bold tracking-tight" style={{ color: "var(--text-primary)" }}>{t("guide.ctaTitle")}</h2>
        <p className="mt-3 text-sm leading-6" style={{ color: "var(--text-secondary)" }}>{t("guide.ctaDesc")}</p>
        <div className="mt-6 flex flex-col gap-3 sm:flex-row">
          <a href="/FamilyFinance.apk" className="rounded-md px-5 py-3 text-center text-sm font-semibold text-white" style={{ backgroundColor: "var(--primary)" }}>
            {t("nav.download")}{apkSize && <span className="ml-2 font-normal opacity-80">{apkSize}</span>}
          </a>
          <Link href="/login?register=1" className="rounded-md border px-5 py-3 text-center text-sm font-semibold" style={{ borderColor: "var(--border)", color: "var(--text-primary)", backgroundColor: "var(--bg-card)" }}>
            {t("guide.ctaBtn")}
          </Link>
        </div>
      </section>
    </div>
  )
}

import { statSync } from "node:fs"
import { join } from "node:path"

import GuideToc from "@/components/public/GuideToc"
import PublicNavbar from "@/components/public/PublicNavbar"
import { Link } from "@/lib/i18n"
import { getTranslations, setRequestLocale } from "next-intl/server"

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

export default async function GuidePage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params
  setRequestLocale(locale)
  const t = await getTranslations()
  const apkSize = apkSizeLabel()
  const toc = [
    ...steps.map(({ n }) => ({ id: `step-${n}`, label: t(`guide.step${n}Title`) })),
    { id: "download", label: t("nav.download") },
  ]

  return (
    <div className="min-h-screen" style={{ backgroundColor: "var(--bg)" }}>
      <PublicNavbar />

      <header className="border-b" style={{ borderColor: "var(--border)" }}>
        <div className="mx-auto max-w-6xl px-5 pb-12 pt-28 sm:px-8 lg:pt-32">
          <p className="text-xs font-semibold uppercase tracking-[0.16em]" style={{ color: "var(--primary)" }}>{t("guide.badge")}</p>
          <h1 className="mt-4 max-w-2xl text-3xl font-semibold leading-tight tracking-[-0.02em] sm:text-4xl" style={{ color: "var(--text-primary)" }}>
            {t("guide.title")}
          </h1>
          <p className="mt-4 max-w-xl text-base leading-7" style={{ color: "var(--text-secondary)" }}>{t("guide.desc")}</p>
        </div>
      </header>

      <div className="mx-auto grid max-w-6xl gap-10 px-5 py-12 sm:px-8 lg:grid-cols-[240px_1fr] lg:gap-16">
        <aside className="lg:sticky lg:top-20 lg:self-start">
          <div className="rounded-lg border p-5 lg:border-0 lg:p-0" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
            <GuideToc title={t("guide.onThisPage")} items={toc} />
          </div>
        </aside>

        <div className="max-w-2xl">
          <ol>
            {steps.map(({ n, details }) => (
              <li key={n} id={`step-${n}`} className="scroll-mt-20 border-t py-10 first:border-t-0 first:pt-0" style={{ borderColor: "var(--border)" }}>
                <span className="text-sm tabular-nums" style={{ color: "var(--text-muted)" }}>{String(n).padStart(2, "0")}</span>
                <h2 className="mt-2 text-xl font-semibold tracking-[-0.01em]" style={{ color: "var(--text-primary)" }}>{t(`guide.step${n}Title`)}</h2>
                <p className="mt-2 text-base leading-7" style={{ color: "var(--text-secondary)" }}>{t(`guide.step${n}Desc`)}</p>
                <ul className="mt-4 space-y-2.5">
                  {Array.from({ length: details }, (_, i) => (
                    <li key={i} className="flex gap-3 text-sm leading-6" style={{ color: "var(--text-secondary)" }}>
                      <span className="mt-2.5 h-px w-3 shrink-0" style={{ backgroundColor: "var(--accent)" }} aria-hidden="true" />
                      {t(`guide.step${n}Detail${i + 1}`)}
                    </li>
                  ))}
                </ul>
              </li>
            ))}
          </ol>

          <section id="download" className="scroll-mt-20 mt-4 rounded-lg border p-7" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
            <h2 className="text-xl font-semibold tracking-[-0.01em]" style={{ color: "var(--text-primary)" }}>{t("guide.ctaTitle")}</h2>
            <p className="mt-2 text-sm leading-7" style={{ color: "var(--text-secondary)" }}>{t("guide.ctaDesc")}</p>
            <div className="mt-6 flex flex-col gap-3 sm:flex-row">
              <a href="/FamilyFinance.apk" className="auth-btn-primary !h-11 !w-auto px-6">
                {t("nav.download")}{apkSize && <span className="ml-1 font-normal opacity-80">· {apkSize}</span>}
              </a>
              <Link href="/login?register=1" className="auth-btn-secondary !h-11 !w-auto px-6">{t("guide.ctaBtn")}</Link>
            </div>
          </section>
        </div>
      </div>
    </div>
  )
}

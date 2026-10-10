import AppPhonePreview from "@/components/public/AppPhonePreview"
import PublicNavbar from "@/components/public/PublicNavbar"
import { Link } from "@/lib/i18n"
import { getTranslations } from "next-intl/server"

const featureKeys = ["overview", "transactions", "budget", "privacy"] as const
const howKeys = ["s1", "s2", "s3"] as const
const factKeys = ["a", "b", "c"] as const

export default async function HomePage() {
  const t = await getTranslations("home")
  return (
    <main className="min-h-screen" style={{ backgroundColor: "var(--bg)" }}>
      <PublicNavbar />

      <section className="mx-auto grid max-w-6xl items-center gap-12 px-5 pb-20 pt-28 sm:px-8 md:grid-cols-[1.15fr_0.85fr] md:gap-16 lg:pt-36">
        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.16em]" style={{ color: "var(--primary)" }}>{t("eyebrow")}</p>
          <h1 className="mt-5 max-w-xl text-[2.6rem] font-semibold leading-[1.08] tracking-[-0.02em] sm:text-[3.25rem]" style={{ color: "var(--text-primary)" }}>
            {t("title")}
          </h1>
          <p className="mt-6 max-w-md text-[1.05rem] leading-8" style={{ color: "var(--text-secondary)" }}>{t("desc")}</p>
          <div className="mt-9 flex flex-col gap-3 sm:flex-row">
            <Link href="/login?register=1" className="auth-btn-primary !h-11 !w-auto px-6">
              {t("ctaPrimary")}
            </Link>
            <a href="/FamilyFinance.apk" className="auth-btn-secondary !h-11 !w-auto px-6">
              {t("ctaApk")}
            </a>
          </div>
          <ul className="mt-8 flex flex-wrap gap-x-6 gap-y-2 text-sm" style={{ color: "var(--text-muted)" }}>
            {factKeys.map((key) => (
              <li key={key} className="flex items-center gap-2">
                <span className="h-1 w-1 rounded-full" style={{ backgroundColor: "var(--accent)" }} />
                {t(`facts.${key}`)}
              </li>
            ))}
          </ul>
        </div>

        <div className="relative mx-auto w-full max-w-sm md:mx-0 md:justify-self-end">
          <div className="absolute -inset-3 -z-0 rounded-xl border" style={{ borderColor: "var(--border)" }} aria-hidden="true" />
          <AppPhonePreview className="relative" />
        </div>
      </section>

      <section className="border-t" style={{ borderColor: "var(--border)" }}>
        <div className="mx-auto max-w-6xl px-5 py-20 sm:px-8">
          <h2 className="text-2xl font-semibold tracking-[-0.01em]" style={{ color: "var(--text-primary)" }}>{t("howTitle")}</h2>
          <ol className="mt-10 grid gap-10 md:grid-cols-3 md:gap-8">
            {howKeys.map((key, i) => (
              <li key={key} className="border-t pt-6" style={{ borderColor: "var(--text-primary)" }}>
                <span className="text-sm tabular-nums" style={{ color: "var(--text-muted)" }}>{String(i + 1).padStart(2, "0")}</span>
                <h3 className="mt-3 text-lg font-semibold" style={{ color: "var(--text-primary)" }}>{t(`how.${key}.title`)}</h3>
                <p className="mt-2 text-sm leading-7" style={{ color: "var(--text-secondary)" }}>{t(`how.${key}.desc`)}</p>
              </li>
            ))}
          </ol>
        </div>
      </section>

      <section id="features" className="scroll-mt-16 border-t" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
        <div className="mx-auto max-w-6xl px-5 py-20 sm:px-8">
          <h2 className="text-2xl font-semibold tracking-[-0.01em]" style={{ color: "var(--text-primary)" }}>{t("featuresTitle")}</h2>
          <div className="mt-10 grid gap-px overflow-hidden rounded-lg border sm:grid-cols-2" style={{ borderColor: "var(--border)", backgroundColor: "var(--border)" }}>
            {featureKeys.map((key) => (
              <div key={key} className="p-7" style={{ backgroundColor: "var(--bg-card)" }}>
                <h3 className="text-base font-semibold" style={{ color: "var(--text-primary)" }}>{t(`features.${key}.title`)}</h3>
                <p className="mt-2 text-sm leading-7" style={{ color: "var(--text-secondary)" }}>{t(`features.${key}.desc`)}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="border-t" style={{ borderColor: "var(--border)" }}>
        <div className="mx-auto flex max-w-6xl flex-col gap-8 px-5 py-20 sm:px-8 md:flex-row md:items-end md:justify-between">
          <div className="max-w-lg">
            <h2 className="text-2xl font-semibold tracking-[-0.01em]" style={{ color: "var(--text-primary)" }}>{t("ctaTitle")}</h2>
            <p className="mt-3 text-sm leading-7" style={{ color: "var(--text-secondary)" }}>{t("ctaDesc")}</p>
          </div>
          <div className="flex flex-col gap-3 sm:flex-row">
            <Link href="/login?register=1" className="auth-btn-primary !h-11 !w-auto px-6">{t("ctaPrimary")}</Link>
            <Link href="/guide" className="auth-btn-secondary !h-11 !w-auto px-6">{t("readGuide")}</Link>
          </div>
        </div>
      </section>

      <footer className="border-t" style={{ borderColor: "var(--border)" }}>
        <div className="mx-auto flex max-w-6xl flex-col gap-2 px-5 py-6 text-xs sm:flex-row sm:justify-between sm:px-8" style={{ color: "var(--text-muted)" }}>
          <span>Family Finance</span>
          <span>{t("footer")}</span>
        </div>
      </footer>
    </main>
  )
}

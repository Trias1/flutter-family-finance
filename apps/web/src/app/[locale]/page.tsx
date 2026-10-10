import AppPhonePreview from "@/components/public/AppPhonePreview"
import PublicNavbar from "@/components/public/PublicNavbar"
import { Link } from "@/lib/i18n"
import { getTranslations } from "next-intl/server"

const featureKeys = ["overview", "transactions", "budget", "privacy"] as const

export default async function HomePage() {
  const t = await getTranslations("home")
  return (
    <main className="min-h-screen" style={{ backgroundColor: "var(--bg)" }}>
      <PublicNavbar />

      <section className="mx-auto grid max-w-6xl items-center gap-12 px-5 pb-16 pt-28 sm:px-8 lg:grid-cols-[1.1fr_0.9fr] lg:pt-36">
        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.14em]" style={{ color: "var(--primary)" }}>{t("eyebrow")}</p>
          <h1 className="mt-4 max-w-xl text-4xl font-bold leading-[1.1] tracking-tight sm:text-5xl" style={{ color: "var(--text-primary)" }}>
            {t("title")}
          </h1>
          <p className="mt-5 max-w-lg text-base leading-7" style={{ color: "var(--text-secondary)" }}>{t("desc")}</p>
          <div className="mt-8 flex flex-col gap-3 sm:flex-row">
            <Link href="/login?register=1" className="rounded-md px-5 py-3 text-center text-sm font-semibold text-white" style={{ backgroundColor: "var(--primary)" }}>
              {t("ctaPrimary")}
            </Link>
            <a href="/FamilyFinance.apk" className="rounded-md border px-5 py-3 text-center text-sm font-semibold" style={{ borderColor: "var(--border)", color: "var(--text-primary)", backgroundColor: "var(--bg-card)" }}>
              {t("ctaApk")}
            </a>
          </div>
          <p className="mt-4 text-xs" style={{ color: "var(--text-muted)" }}>{t("ctaNote")}</p>
        </div>

        <div className="mx-auto w-full max-w-sm">
          <AppPhonePreview />
        </div>
      </section>

      <section id="features" className="border-t" style={{ borderColor: "var(--border)" }}>
        <div className="mx-auto grid max-w-6xl gap-x-10 gap-y-8 px-5 py-14 sm:px-8 md:grid-cols-2 lg:grid-cols-4">
          {featureKeys.map((key) => (
            <div key={key}>
              <h2 className="text-sm font-semibold" style={{ color: "var(--text-primary)" }}>{t(`features.${key}.title`)}</h2>
              <p className="mt-2 text-sm leading-6" style={{ color: "var(--text-secondary)" }}>{t(`features.${key}.desc`)}</p>
            </div>
          ))}
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

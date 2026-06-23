import AppThemedBackground from "@/components/public/AppThemedBackground"
import PublicNavbar from "@/components/public/PublicNavbar"
import { Link } from "@/lib/i18n"
import { getTranslations } from "next-intl/server"

export default async function GuidePage() {
  const t = await getTranslations()
  const steps = [
    { step: "01", title: t("marketing.step1Title"), desc: t("marketing.step1Desc") },
    { step: "02", title: t("marketing.step2Title"), desc: t("marketing.step2Desc") },
    { step: "03", title: t("marketing.step3Title"), desc: t("marketing.step3Desc") },
    { step: "04", title: t("marketing.step4Title"), desc: t("marketing.step4Desc") },
  ]
  return (
    <div className="min-h-screen bg-[#050505] text-white">
      <section className="relative overflow-hidden border-b border-white/10 px-6 pb-20 pt-32">
        <AppThemedBackground compact />
        <div className="absolute inset-0 bg-gradient-to-b from-black/30 via-black/55 to-[#050505]" />
        <PublicNavbar />

        <div className="relative z-10 mx-auto max-w-5xl pt-20 text-center">
          <p className="text-sm uppercase tracking-[0.32em] text-white/60">{t("marketing.documentation")}</p>
          <h1 className="mt-6 text-balance text-[42px] font-semibold tracking-[-0.04em] sm:text-[64px]">
            {t("marketing.guideTitle")}
          </h1>
          <p className="mx-auto mt-5 max-w-[620px] text-[15px] leading-7 text-white/72">
            {t("marketing.guideDesc")}
          </p>
        </div>
      </section>

      <section id="features" className="mx-auto max-w-6xl px-6 py-20">
        <div className="grid gap-5 lg:grid-cols-2">
          {steps.map((step) => (
            <div key={step.step} className="rounded-[2rem] border border-white/10 bg-white/[0.04] p-7 backdrop-blur-md">
              <p className="text-xs font-medium uppercase tracking-[0.32em] text-[#66BB6A]">{step.step}</p>
              <h2 className="mt-4 text-2xl font-semibold tracking-[-0.03em]">{step.title}</h2>
              <p className="mt-3 text-sm leading-7 text-white/68">{step.desc}</p>
            </div>
          ))}
        </div>
      </section>

      <section id="download" className="mx-auto max-w-6xl px-6 pb-24">
        <div className="rounded-[2.5rem] border border-white/10 bg-gradient-to-br from-white/[0.07] via-white/[0.03] to-transparent p-8 sm:p-12">
          <div className="grid gap-10 lg:grid-cols-[1.2fr,0.8fr] lg:items-end">
            <div>
              <p className="text-sm uppercase tracking-[0.28em] text-white/55">{t("marketing.downloadAccess")}</p>
              <h2 className="mt-4 text-[34px] font-semibold tracking-[-0.04em] sm:text-[48px]">
                {t("marketing.startAndroidMonitorWeb")}
              </h2>
              <p className="mt-4 max-w-[560px] text-[15px] leading-7 text-white/68">
                {t("marketing.downloadDesc")}
              </p>
            </div>

            <div className="flex flex-col gap-3 sm:items-start lg:items-end">
              <a href="/FamilyFinance.apk" className="inline-flex items-center gap-3 rounded-xl bg-white px-6 py-3 text-[13px] font-medium text-black transition-transform hover:scale-[1.02]">
                Download APK <span className="text-black/45">(67.7 MB)</span>
              </a>
              <Link href="/login?register=1" className="inline-flex items-center gap-3 rounded-xl border border-white/15 px-6 py-3 text-[13px] font-medium text-white transition-colors hover:bg-white/5">
                {t("marketing.createAccount")}
              </Link>
            </div>
          </div>
        </div>
      </section>
    </div>
  )
}

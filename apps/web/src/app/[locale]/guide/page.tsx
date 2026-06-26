import AppThemedBackground from "@/components/public/AppThemedBackground"
import PublicNavbar from "@/components/public/PublicNavbar"
import { Link } from "@/lib/i18n"
import { getTranslations } from "next-intl/server"

export default async function GuidePage() {
  const t = await getTranslations()

  return (
    <div className="min-h-screen bg-[#050505] text-white">
      <section className="relative overflow-hidden border-b border-white/10 px-6 pb-20 pt-32">
        <AppThemedBackground compact />
        <div className="absolute inset-0 bg-gradient-to-b from-black/30 via-black/55 to-[#050505]" />
        <PublicNavbar />

        <div className="relative z-10 mx-auto max-w-5xl pt-20 text-center">
          <p className="text-sm uppercase tracking-[0.32em] text-white/60">{t("guide.badge")}</p>
          <h1 className="mt-6 text-balance text-[42px] font-semibold tracking-[-0.04em] sm:text-[64px]">
            {t("guide.title")}
          </h1>
          <p className="mx-auto mt-5 max-w-[620px] text-[15px] leading-7 text-white/72">
            {t("guide.desc")}
          </p>
        </div>
      </section>

      <section className="mx-auto max-w-4xl px-6 py-16">
        <div className="space-y-12">
          <div className="rounded-[2rem] border border-white/10 bg-white/[0.04] p-8 backdrop-blur-md">
            <div className="mb-4 flex items-center gap-3">
              <span className="rounded-full bg-[#D97706]/20 px-3 py-1 text-xs font-medium uppercase tracking-wider text-[#D97706]">01</span>
              <h2 className="text-2xl font-semibold">{t("guide.step1Title")}</h2>
            </div>
            <p className="mb-4 text-white/68">{t("guide.step1Desc")}</p>
            <ul className="space-y-2 text-sm text-white/60">
              <li className="flex items-start gap-2"><span className="text-[#D97706]">•</span>{t("guide.step1Detail1")}</li>
              <li className="flex items-start gap-2"><span className="text-[#D97706]">•</span>{t("guide.step1Detail2")}</li>
              <li className="flex items-start gap-2"><span className="text-[#D97706]">•</span>{t("guide.step1Detail3")}</li>
            </ul>
          </div>

          <div className="rounded-[2rem] border border-white/10 bg-white/[0.04] p-8 backdrop-blur-md">
            <div className="mb-4 flex items-center gap-3">
              <span className="rounded-full bg-[#42A5F5]/20 px-3 py-1 text-xs font-medium uppercase tracking-wider text-[#42A5F5]">02</span>
              <h2 className="text-2xl font-semibold">{t("guide.step2Title")}</h2>
            </div>
            <p className="mb-4 text-white/68">{t("guide.step2Desc")}</p>
            <ul className="space-y-2 text-sm text-white/60">
              <li className="flex items-start gap-2"><span className="text-[#42A5F5]">•</span>{t("guide.step2Detail1")}</li>
              <li className="flex items-start gap-2"><span className="text-[#42A5F5]">•</span>{t("guide.step2Detail2")}</li>
              <li className="flex items-start gap-2"><span className="text-[#42A5F5]">•</span>{t("guide.step2Detail3")}</li>
              <li className="flex items-start gap-2"><span className="text-[#42A5F5]">•</span>{t("guide.step2Detail4")}</li>
            </ul>
          </div>

          <div className="rounded-[2rem] border border-white/10 bg-white/[0.04] p-8 backdrop-blur-md">
            <div className="mb-4 flex items-center gap-3">
              <span className="rounded-full bg-[#FFA726]/20 px-3 py-1 text-xs font-medium uppercase tracking-wider text-[#FFA726]">03</span>
              <h2 className="text-2xl font-semibold">{t("guide.step3Title")}</h2>
            </div>
            <p className="mb-4 text-white/68">{t("guide.step3Desc")}</p>
            <ul className="space-y-2 text-sm text-white/60">
              <li className="flex items-start gap-2"><span className="text-[#FFA726]">•</span>{t("guide.step3Detail1")}</li>
              <li className="flex items-start gap-2"><span className="text-[#FFA726]">•</span>{t("guide.step3Detail2")}</li>
              <li className="flex items-start gap-2"><span className="text-[#FFA726]">•</span>{t("guide.step3Detail3")}</li>
              <li className="flex items-start gap-2"><span className="text-[#FFA726]">•</span>{t("guide.step3Detail4")}</li>
            </ul>
          </div>

          <div className="rounded-[2rem] border border-white/10 bg-white/[0.04] p-8 backdrop-blur-md">
            <div className="mb-4 flex items-center gap-3">
              <span className="rounded-full bg-[#EF5350]/20 px-3 py-1 text-xs font-medium uppercase tracking-wider text-[#EF5350]">04</span>
              <h2 className="text-2xl font-semibold">{t("guide.step4Title")}</h2>
            </div>
            <p className="mb-4 text-white/68">{t("guide.step4Desc")}</p>
            <ul className="space-y-2 text-sm text-white/60">
              <li className="flex items-start gap-2"><span className="text-[#EF5350]">•</span>{t("guide.step4Detail1")}</li>
              <li className="flex items-start gap-2"><span className="text-[#EF5350]">•</span>{t("guide.step4Detail2")}</li>
              <li className="flex items-start gap-2"><span className="text-[#EF5350]">•</span>{t("guide.step4Detail3")}</li>
              <li className="flex items-start gap-2"><span className="text-[#EF5350]">•</span>{t("guide.step4Detail4")}</li>
            </ul>
          </div>

          <div className="rounded-[2rem] border border-white/10 bg-white/[0.04] p-8 backdrop-blur-md">
            <div className="mb-4 flex items-center gap-3">
              <span className="rounded-full bg-[#AB47BC]/20 px-3 py-1 text-xs font-medium uppercase tracking-wider text-[#AB47BC]">05</span>
              <h2 className="text-2xl font-semibold">{t("guide.step5Title")}</h2>
            </div>
            <p className="mb-4 text-white/68">{t("guide.step5Desc")}</p>
            <ul className="space-y-2 text-sm text-white/60">
              <li className="flex items-start gap-2"><span className="text-[#AB47BC]">•</span>{t("guide.step5Detail1")}</li>
              <li className="flex items-start gap-2"><span className="text-[#AB47BC]">•</span>{t("guide.step5Detail2")}</li>
              <li className="flex items-start gap-2"><span className="text-[#AB47BC]">•</span>{t("guide.step5Detail3")}</li>
              <li className="flex items-start gap-2"><span className="text-[#AB47BC]">•</span>{t("guide.step5Detail4")}</li>
            </ul>
          </div>

          <div className="rounded-[2rem] border border-white/10 bg-white/[0.04] p-8 backdrop-blur-md">
            <div className="mb-4 flex items-center gap-3">
              <span className="rounded-full bg-[#26A69A]/20 px-3 py-1 text-xs font-medium uppercase tracking-wider text-[#26A69A]">06</span>
              <h2 className="text-2xl font-semibold">{t("guide.step6Title")}</h2>
            </div>
            <p className="mb-4 text-white/68">{t("guide.step6Desc")}</p>
            <ul className="space-y-2 text-sm text-white/60">
              <li className="flex items-start gap-2"><span className="text-[#26A69A]">•</span>{t("guide.step6Detail1")}</li>
              <li className="flex items-start gap-2"><span className="text-[#26A69A]">•</span>{t("guide.step6Detail2")}</li>
              <li className="flex items-start gap-2"><span className="text-[#26A69A]">•</span>{t("guide.step6Detail3")}</li>
              <li className="flex items-start gap-2"><span className="text-[#26A69A]">•</span>{t("guide.step6Detail4")}</li>
            </ul>
          </div>

          <div className="rounded-[2rem] border border-white/10 bg-white/[0.04] p-8 backdrop-blur-md">
            <div className="mb-4 flex items-center gap-3">
              <span className="rounded-full bg-[#5C6BC0]/20 px-3 py-1 text-xs font-medium uppercase tracking-wider text-[#5C6BC0]">07</span>
              <h2 className="text-2xl font-semibold">{t("guide.step7Title")}</h2>
            </div>
            <p className="mb-4 text-white/68">{t("guide.step7Desc")}</p>
            <ul className="space-y-2 text-sm text-white/60">
              <li className="flex items-start gap-2"><span className="text-[#5C6BC0]">•</span>{t("guide.step7Detail1")}</li>
              <li className="flex items-start gap-2"><span className="text-[#5C6BC0]">•</span>{t("guide.step7Detail2")}</li>
              <li className="flex items-start gap-2"><span className="text-[#5C6BC0]">•</span>{t("guide.step7Detail3")}</li>
              <li className="flex items-start gap-2"><span className="text-[#5C6BC0]">•</span>{t("guide.step7Detail4")}</li>
            </ul>
          </div>

          <div className="rounded-[2rem] border border-white/10 bg-white/[0.04] p-8 backdrop-blur-md">
            <div className="mb-4 flex items-center gap-3">
              <span className="rounded-full bg-[#EC407A]/20 px-3 py-1 text-xs font-medium uppercase tracking-wider text-[#EC407A]">08</span>
              <h2 className="text-2xl font-semibold">{t("guide.step8Title")}</h2>
            </div>
            <p className="mb-4 text-white/68">{t("guide.step8Desc")}</p>
            <ul className="space-y-2 text-sm text-white/60">
              <li className="flex items-start gap-2"><span className="text-[#EC407A]">•</span>{t("guide.step8Detail1")}</li>
              <li className="flex items-start gap-2"><span className="text-[#EC407A]">•</span>{t("guide.step8Detail2")}</li>
              <li className="flex items-start gap-2"><span className="text-[#EC407A]">•</span>{t("guide.step8Detail3")}</li>
              <li className="flex items-start gap-2"><span className="text-[#EC407A]">•</span>{t("guide.step8Detail4")}</li>
            </ul>
          </div>
        </div>
      </section>

      <section className="mx-auto max-w-4xl px-6 pb-20">
        <div className="rounded-[2.5rem] border border-white/10 bg-gradient-to-br from-white/[0.07] via-white/[0.03] to-transparent p-8 text-center sm:p-12">
          <h2 className="text-[34px] font-semibold tracking-[-0.04em] sm:text-[48px]">
            {t("guide.ctaTitle")}
          </h2>
          <p className="mx-auto mt-4 max-w-[560px] text-[15px] leading-7 text-white/68">
            {t("guide.ctaDesc")}
          </p>
          <div className="mt-8 flex flex-col items-center gap-4 sm:flex-row sm:justify-center">
            <a href="/FamilyFinance.apk" className="inline-flex items-center gap-3 rounded-xl bg-white px-6 py-3 text-[13px] font-medium text-black transition-transform hover:scale-[1.02]">
              {t("nav.download")} <span className="text-black/45">(86.9 MB)</span>
            </a>
            <Link href="/login?register=1" className="inline-flex items-center gap-3 rounded-xl border border-white/15 px-6 py-3 text-[13px] font-medium text-white transition-colors hover:bg-white/5">
              {t("guide.ctaBtn")}
            </Link>
          </div>
        </div>
      </section>
    </div>
  )
}

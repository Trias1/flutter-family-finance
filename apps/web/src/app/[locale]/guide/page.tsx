import AppThemedBackground from "@/components/public/AppThemedBackground"
import PublicNavbar from "@/components/public/PublicNavbar"
import { Link } from "@/lib/i18n"
import { getTranslations } from "next-intl/server"

export default async function GuidePage() {
  const t = await getTranslations()

  return (
    <div className="banking-page-bg min-h-screen">
      <section className="relative overflow-hidden px-6 pb-20 pt-32">
        
        <div className="absolute inset-0 bg-[radial-gradient(circle_at_top_left,rgba(184,216,200,0.48),transparent_30rem)]" />
        <PublicNavbar />

        <div className="relative z-10 mx-auto max-w-5xl pt-20 text-center">
          <p className="text-fluid-sm font-bold uppercase tracking-[0.32em]" style={{ color: "var(--primary)" }}>{t("guide.badge")}</p>
          <h1 className="mt-6 text-balance responsive-hero-title font-black" style={{ color: "var(--text-primary)" }}>
            {t("guide.title")}
          </h1>
          <p className="mx-auto mt-5 max-w-[620px] text-[15px] leading-7" style={{ color: "var(--text-secondary)" }}>
            {t("guide.desc")}
          </p>
        </div>
      </section>

      <section className="mx-auto max-w-4xl px-6 py-16">
        <div className="space-y-12">
          <div className="rounded-[2rem] p-8 glass-card">
            <div className="mb-4 flex items-center gap-3">
              <span className="rounded-full bg-[#D97706]/20 px-3 py-1 text-xs font-medium uppercase tracking-wider text-blue-600">01</span>
              <h2 className="text-2xl font-bold" style={{ color: "var(--text-primary)" }}>{t("guide.step1Title")}</h2>
            </div>
            <p className="mb-4" style={{ color: "var(--text-secondary)" }}>{t("guide.step1Desc")}</p>
            <ul className="space-y-2 text-sm" style={{ color: "var(--text-secondary)" }}>
              <li className="flex items-start gap-2"><span className="text-blue-600">•</span>{t("guide.step1Detail1")}</li>
              <li className="flex items-start gap-2"><span className="text-blue-600">•</span>{t("guide.step1Detail2")}</li>
              <li className="flex items-start gap-2"><span className="text-blue-600">•</span>{t("guide.step1Detail3")}</li>
            </ul>
          </div>

          <div className="rounded-[2rem] p-8 glass-card">
            <div className="mb-4 flex items-center gap-3">
              <span className="rounded-full bg-[#42A5F5]/20 px-3 py-1 text-xs font-medium uppercase tracking-wider text-cyan-600">02</span>
              <h2 className="text-2xl font-bold" style={{ color: "var(--text-primary)" }}>{t("guide.step2Title")}</h2>
            </div>
            <p className="mb-4" style={{ color: "var(--text-secondary)" }}>{t("guide.step2Desc")}</p>
            <ul className="space-y-2 text-sm" style={{ color: "var(--text-secondary)" }}>
              <li className="flex items-start gap-2"><span className="text-cyan-600">•</span>{t("guide.step2Detail1")}</li>
              <li className="flex items-start gap-2"><span className="text-cyan-600">•</span>{t("guide.step2Detail2")}</li>
              <li className="flex items-start gap-2"><span className="text-cyan-600">•</span>{t("guide.step2Detail3")}</li>
              <li className="flex items-start gap-2"><span className="text-cyan-600">•</span>{t("guide.step2Detail4")}</li>
            </ul>
          </div>

          <div className="rounded-[2rem] p-8 glass-card">
            <div className="mb-4 flex items-center gap-3">
              <span className="rounded-full bg-[#FFA726]/20 px-3 py-1 text-xs font-medium uppercase tracking-wider text-amber-600">03</span>
              <h2 className="text-2xl font-bold" style={{ color: "var(--text-primary)" }}>{t("guide.step3Title")}</h2>
            </div>
            <p className="mb-4" style={{ color: "var(--text-secondary)" }}>{t("guide.step3Desc")}</p>
            <ul className="space-y-2 text-sm" style={{ color: "var(--text-secondary)" }}>
              <li className="flex items-start gap-2"><span className="text-amber-600">•</span>{t("guide.step3Detail1")}</li>
              <li className="flex items-start gap-2"><span className="text-amber-600">•</span>{t("guide.step3Detail2")}</li>
              <li className="flex items-start gap-2"><span className="text-amber-600">•</span>{t("guide.step3Detail3")}</li>
              <li className="flex items-start gap-2"><span className="text-amber-600">•</span>{t("guide.step3Detail4")}</li>
            </ul>
          </div>

          <div className="rounded-[2rem] p-8 glass-card">
            <div className="mb-4 flex items-center gap-3">
              <span className="rounded-full bg-[#EF5350]/20 px-3 py-1 text-xs font-medium uppercase tracking-wider text-red-500">04</span>
              <h2 className="text-2xl font-bold" style={{ color: "var(--text-primary)" }}>{t("guide.step4Title")}</h2>
            </div>
            <p className="mb-4" style={{ color: "var(--text-secondary)" }}>{t("guide.step4Desc")}</p>
            <ul className="space-y-2 text-sm" style={{ color: "var(--text-secondary)" }}>
              <li className="flex items-start gap-2"><span className="text-red-500">•</span>{t("guide.step4Detail1")}</li>
              <li className="flex items-start gap-2"><span className="text-red-500">•</span>{t("guide.step4Detail2")}</li>
              <li className="flex items-start gap-2"><span className="text-red-500">•</span>{t("guide.step4Detail3")}</li>
              <li className="flex items-start gap-2"><span className="text-red-500">•</span>{t("guide.step4Detail4")}</li>
            </ul>
          </div>

          <div className="rounded-[2rem] p-8 glass-card">
            <div className="mb-4 flex items-center gap-3">
              <span className="rounded-full bg-[#AB47BC]/20 px-3 py-1 text-xs font-medium uppercase tracking-wider text-indigo-600">05</span>
              <h2 className="text-2xl font-bold" style={{ color: "var(--text-primary)" }}>{t("guide.step5Title")}</h2>
            </div>
            <p className="mb-4" style={{ color: "var(--text-secondary)" }}>{t("guide.step5Desc")}</p>
            <ul className="space-y-2 text-sm" style={{ color: "var(--text-secondary)" }}>
              <li className="flex items-start gap-2"><span className="text-indigo-600">•</span>{t("guide.step5Detail1")}</li>
              <li className="flex items-start gap-2"><span className="text-indigo-600">•</span>{t("guide.step5Detail2")}</li>
              <li className="flex items-start gap-2"><span className="text-indigo-600">•</span>{t("guide.step5Detail3")}</li>
              <li className="flex items-start gap-2"><span className="text-indigo-600">•</span>{t("guide.step5Detail4")}</li>
            </ul>
          </div>

          <div className="rounded-[2rem] p-8 glass-card">
            <div className="mb-4 flex items-center gap-3">
              <span className="rounded-full bg-[#26A69A]/20 px-3 py-1 text-xs font-medium uppercase tracking-wider text-emerald-600">06</span>
              <h2 className="text-2xl font-bold" style={{ color: "var(--text-primary)" }}>{t("guide.step6Title")}</h2>
            </div>
            <p className="mb-4" style={{ color: "var(--text-secondary)" }}>{t("guide.step6Desc")}</p>
            <ul className="space-y-2 text-sm" style={{ color: "var(--text-secondary)" }}>
              <li className="flex items-start gap-2"><span className="text-emerald-600">•</span>{t("guide.step6Detail1")}</li>
              <li className="flex items-start gap-2"><span className="text-emerald-600">•</span>{t("guide.step6Detail2")}</li>
              <li className="flex items-start gap-2"><span className="text-emerald-600">•</span>{t("guide.step6Detail3")}</li>
              <li className="flex items-start gap-2"><span className="text-emerald-600">•</span>{t("guide.step6Detail4")}</li>
            </ul>
          </div>

          <div className="rounded-[2rem] p-8 glass-card">
            <div className="mb-4 flex items-center gap-3">
              <span className="rounded-full bg-[#5C6BC0]/20 px-3 py-1 text-xs font-medium uppercase tracking-wider text-blue-700">07</span>
              <h2 className="text-2xl font-bold" style={{ color: "var(--text-primary)" }}>{t("guide.step7Title")}</h2>
            </div>
            <p className="mb-4" style={{ color: "var(--text-secondary)" }}>{t("guide.step7Desc")}</p>
            <ul className="space-y-2 text-sm" style={{ color: "var(--text-secondary)" }}>
              <li className="flex items-start gap-2"><span className="text-blue-700">•</span>{t("guide.step7Detail1")}</li>
              <li className="flex items-start gap-2"><span className="text-blue-700">•</span>{t("guide.step7Detail2")}</li>
              <li className="flex items-start gap-2"><span className="text-blue-700">•</span>{t("guide.step7Detail3")}</li>
              <li className="flex items-start gap-2"><span className="text-blue-700">•</span>{t("guide.step7Detail4")}</li>
            </ul>
          </div>

          <div className="rounded-[2rem] p-8 glass-card">
            <div className="mb-4 flex items-center gap-3">
              <span className="rounded-full bg-[#EC407A]/20 px-3 py-1 text-xs font-medium uppercase tracking-wider text-rose-500">08</span>
              <h2 className="text-2xl font-bold" style={{ color: "var(--text-primary)" }}>{t("guide.step8Title")}</h2>
            </div>
            <p className="mb-4" style={{ color: "var(--text-secondary)" }}>{t("guide.step8Desc")}</p>
            <ul className="space-y-2 text-sm" style={{ color: "var(--text-secondary)" }}>
              <li className="flex items-start gap-2"><span className="text-rose-500">•</span>{t("guide.step8Detail1")}</li>
              <li className="flex items-start gap-2"><span className="text-rose-500">•</span>{t("guide.step8Detail2")}</li>
              <li className="flex items-start gap-2"><span className="text-rose-500">•</span>{t("guide.step8Detail3")}</li>
              <li className="flex items-start gap-2"><span className="text-rose-500">•</span>{t("guide.step8Detail4")}</li>
            </ul>
          </div>
        </div>
      </section>

      <section className="mx-auto max-w-4xl px-6 pb-20">
        <div className="rounded-[2.5rem] p-8 text-center glass-card sm:p-12">
          <h2 className="text-[34px] font-black tracking-[-0.04em] sm:text-[48px]" style={{ color: "var(--text-primary)" }}>
            {t("guide.ctaTitle")}
          </h2>
          <p className="mx-auto mt-4 max-w-[560px] text-[15px] leading-7" style={{ color: "var(--text-secondary)" }}>
            {t("guide.ctaDesc")}
          </p>
          <div className="mt-8 flex flex-col items-center gap-4 sm:flex-row sm:justify-center">
            <a href="/FamilyFinance.apk" className="inline-flex items-center gap-3 rounded-2xl px-6 py-3 text-[13px] font-bold text-white transition-transform hover:scale-[1.02]" style={{ backgroundColor: "var(--primary)" }}>
              {t("nav.download")} <span className="text-white/70">(86.9 MB)</span>
            </a>
            <Link href="/login?register=1" className="inline-flex items-center gap-3 rounded-2xl px-6 py-3 text-[13px] font-bold transition-transform hover:scale-[1.02] glass-card">
              {t("guide.ctaBtn")}
            </Link>
          </div>
        </div>
      </section>
    </div>
  )
}




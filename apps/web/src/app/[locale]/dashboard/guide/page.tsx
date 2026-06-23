"use client"

import { useTranslations } from "next-intl"
import DashboardShell from "@/components/DashboardShell"

const steps = [
  {
    step: 1, icon: "👤",
    titleKey: "step1Title", descKey: "step1Desc",
    detailKeys: ["step1Detail1", "step1Detail2", "step1Detail3"],
  },
  {
    step: 2, icon: "👨‍👩‍👧‍👦",
    titleKey: "step2Title", descKey: "step2Desc",
    detailKeys: ["step2Detail1", "step2Detail2", "step2Detail3", "step2Detail4"],
  },
  {
    step: 3, icon: "👛",
    titleKey: "step3Title", descKey: "step3Desc",
    detailKeys: ["step3Detail1", "step3Detail2", "step3Detail3", "step3Detail4"],
  },
  {
    step: 4, icon: "💰",
    titleKey: "step4Title", descKey: "step4Desc",
    detailKeys: ["step4Detail1", "step4Detail2", "step4Detail3", "step4Detail4"],
  },
  {
    step: 5, icon: "🎯",
    titleKey: "step5Title", descKey: "step5Desc",
    detailKeys: ["step5Detail1", "step5Detail2", "step5Detail3", "step5Detail4"],
  },
  {
    step: 6, icon: "📋",
    titleKey: "step6Title", descKey: "step6Desc",
    detailKeys: ["step6Detail1", "step6Detail2", "step6Detail3", "step6Detail4"],
  },
  {
    step: 7, icon: "📊",
    titleKey: "step7Title", descKey: "step7Desc",
    detailKeys: ["step7Detail1", "step7Detail2", "step7Detail3", "step7Detail4"],
  },
  {
    step: 8, icon: "🔐",
    titleKey: "step8Title", descKey: "step8Desc",
    detailKeys: ["step8Detail1", "step8Detail2", "step8Detail3", "step8Detail4"],
  },
]

export default function DashboardGuidePage() {
  const t = useTranslations()

  return (
    <DashboardShell>
      <div className="max-w-3xl mx-auto space-y-8">
        <div className="text-center">
          <h1 className="text-2xl font-bold" style={{ color: "var(--text-primary)" }}>{t("guide.title")} Family Finance</h1>
          <p className="mt-2 text-sm" style={{ color: "var(--text-secondary)" }}>{t("guide.desc")}</p>
        </div>

        {steps.map((s, i) => (
          <div key={i} className="rounded-2xl border p-6 lg:p-8 transition-all hover:shadow-md" style={{ borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }}>
            <div className="flex items-start gap-5">
              <div className="flex h-14 w-14 shrink-0 items-center justify-center rounded-2xl text-2xl" style={{ backgroundColor: "var(--primary-bg)" }}>{s.icon}</div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-3 mb-1">
                  <span className="flex h-7 w-7 items-center justify-center rounded-full text-xs font-bold text-white" style={{ backgroundColor: "var(--primary)" }}>{s.step}</span>
                  <h3 className="text-lg font-semibold" style={{ color: "var(--text-primary)" }}>{t(`guide.${s.titleKey}`)}</h3>
                </div>
                <p className="mt-1 text-sm" style={{ color: "var(--text-secondary)" }}>{t(`guide.${s.descKey}`)}</p>
                <ul className="mt-3 space-y-1.5">
                  {s.detailKeys.map((dk, j) => (
                    <li key={j} className="flex items-start gap-2 text-sm" style={{ color: "var(--text-secondary)" }}>
                      <span className="mt-1.5 h-1.5 w-1.5 rounded-full shrink-0" style={{ backgroundColor: "var(--primary-light)" }} />
                      {t(`guide.${dk}`)}
                    </li>
                  ))}
                </ul>
              </div>
            </div>
          </div>
        ))}
      </div>
    </DashboardShell>
  )
}

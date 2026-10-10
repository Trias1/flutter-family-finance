import AppPhonePreview from "@/components/public/AppPhonePreview"
import PublicNavbar from "@/components/public/PublicNavbar"
import { Link } from "@/lib/i18n"
import { getTranslations } from "next-intl/server"

const features = [
    { title: "Account overview", desc: "Saldo, income, expense, dan sisa bulan ini tampil seperti banking dashboard modern.", icon: "$" },
    { title: "Smart transactions", desc: "Riwayat transaksi keluarga tetap mudah discan dengan kategori dan status yang jelas.", icon: "TX" },
    { title: "Secure by design", desc: "Firebase Auth, role super admin, dan data family menjaga akses tetap terkontrol.", icon: "OK" },
]

const securityHighlights = ["Role-based access", "Firebase secured", "Private family data", "Android + web sync"]

export default async function HomePage() {
  const t = await getTranslations()
  return (
    <main className="banking-page-bg min-h-screen overflow-hidden">
      <PublicNavbar />

      <section className="relative mx-auto grid min-h-screen max-w-7xl items-center gap-12 px-6 pb-20 pt-32 lg:grid-cols-[1.04fr_0.96fr] lg:px-10">
        <div className="pointer-events-none absolute left-10 top-24 h-72 w-72 rounded-full bg-blue-500/20 blur-3xl" />
        <div className="pointer-events-none absolute right-12 top-32 h-72 w-72 rounded-full bg-cyan-400/20 blur-3xl" />

        <div className="relative z-10">
          <div className="mb-6 inline-flex items-center gap-2 rounded-full px-4 py-2 text-fluid-sm font-bold glass-card" style={{ color: "var(--primary)" }}>
            <span className="h-2 w-2 rounded-full bg-emerald-500" />
            Trusted family finance dashboard
          </div>
          <h1 className="text-balance responsive-hero-title font-black" style={{ color: "var(--text-primary)" }}>
            Digital banking feel untuk <span className="trust-gradient-text">keuangan keluarga.</span>
          </h1>
          <p className="mt-6 max-w-2xl responsive-copy" style={{ color: "var(--text-secondary)" }}>
            {t("marketing.homeDesc")} Web app sekarang dibuat lebih sleek dengan glassmorphism cards, account preview, security highlights, dan CTA download mobile app.
          </p>
          <div className="mt-8 flex flex-col gap-4 sm:flex-row">
            <Link href="/login?register=1" className="rounded-2xl px-6 py-3 text-center text-fluid-sm font-bold text-white shadow-lg transition-transform hover:-translate-y-0.5" style={{ backgroundColor: "var(--primary)" }}>
              {t("marketing.getStarted")}
            </Link>
            <a href="/FamilyFinance.apk" className="rounded-2xl px-6 py-3 text-center text-fluid-sm font-bold transition-transform hover:-translate-y-0.5 glass-card" style={{ color: "var(--primary)" }}>
              {t("nav.download")}
            </a>
          </div>

          <div className="mt-9 flex flex-wrap gap-3">
            {securityHighlights.map((item) => (
              <span key={item} className="rounded-full px-4 py-2 text-xs font-bold glass-card" style={{ color: "var(--text-secondary)" }}>{item}</span>
            ))}
          </div>
        </div>

        <div className="relative z-10 mx-auto w-full max-w-xl">
          <div className="absolute -left-5 top-10 rounded-3xl p-4 text-white glass-panel-dark">
            <p className="text-xs text-white/60">Total balance</p>
            <p className="mt-1 text-2xl font-black">Rp12.5jt</p>
            <p className="mt-2 text-xs text-emerald-300">+18% cashflow sehat</p>
          </div>
          <div className="absolute -right-3 bottom-12 z-20 rounded-3xl p-4 glass-card">
            <p className="text-xs font-bold" style={{ color: "var(--text-muted)" }}>Security</p>
            <p className="mt-1 text-fluid-sm font-black" style={{ color: "var(--text-primary)" }}>Protected access</p>
          </div>
          <div className="rounded-[2.5rem] p-6 glass-card">
            <AppPhonePreview />
          </div>
        </div>
      </section>

      <section id="features" className="mx-auto max-w-7xl px-6 pb-24 lg:px-10">
        <div className="grid gap-5 md:grid-cols-3">
          {features.map((feature) => (
            <div key={feature.title} className="rounded-[2rem] p-7 glass-card">
              <div className="flex h-12 w-12 items-center justify-center rounded-2xl text-xl font-black text-white" style={{ backgroundColor: "var(--primary)" }}>{feature.icon}</div>
              <h2 className="mt-6 text-xl font-black" style={{ color: "var(--text-primary)" }}>{feature.title}</h2>
              <p className="mt-3 text-fluid-sm leading-6" style={{ color: "var(--text-secondary)" }}>{feature.desc}</p>
            </div>
          ))}
        </div>
      </section>
    </main>
  )
}





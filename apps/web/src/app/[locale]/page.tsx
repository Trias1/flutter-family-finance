import AppThemedBackground from "@/components/public/AppThemedBackground"
import PublicNavbar from "@/components/public/PublicNavbar"
import { Link } from "@/lib/i18n"
import { getTranslations } from "next-intl/server"

export default async function HomePage() {
  const t = await getTranslations()
  return (
    <section className="relative h-screen w-full overflow-hidden bg-[#050505]">
      <AppThemedBackground />
      <div className="absolute inset-0 bg-gradient-to-b from-black/10 via-black/20 to-black/60" />

      <PublicNavbar />

      <div className="absolute bottom-8 left-0 right-0 z-20 flex flex-col items-center px-6 text-center">
        <div className="flex flex-col items-center text-center">
          <h1 className="text-balance text-[42px] font-semibold tracking-[-0.04em] text-white sm:text-[56px]">
            {t("marketing.homeTitle")}
          </h1>
          <p className="mt-5 max-w-[420px] text-[15px] leading-7 text-[#D1D1D1]">
            {t("marketing.homeDesc")}
          </p>
          <Link href="/login?register=1" className="mt-7 rounded-xl bg-white px-6 py-2.5 text-[13px] font-medium text-black transition-transform hover:scale-[1.02]">
            {t("marketing.getStarted")}
          </Link>
        </div>
      </div>
    </section>
  )
}

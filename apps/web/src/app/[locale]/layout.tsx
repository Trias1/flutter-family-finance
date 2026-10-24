import "../globals.css"
import type { Metadata } from "next"
import { Geist_Mono, Plus_Jakarta_Sans } from "next/font/google"
import { notFound } from "next/navigation"
import { NextIntlClientProvider, hasLocale } from "next-intl"
import { getMessages, getTranslations, setRequestLocale } from "next-intl/server"
import { locales } from "@/lib/i18n"
import { themeScript } from "@/lib/theme-script"

const plusJakartaSans = Plus_Jakarta_Sans({
  variable: "--font-plus-jakarta-sans",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
})

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
})

type Props = { params: Promise<{ locale: string }> }

// /en and /id are prerendered; the app routes (login, dashboard, admin) opt
// back into per-request rendering in their own layouts for the CSP nonce.
export function generateStaticParams() {
  return locales.map((locale) => ({ locale }))
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { locale } = await params
  const t = await getTranslations({ locale, namespace: "meta" })
  return {
    title: {
      default: t("title"),
      template: "%s | Family Finance",
    },
    description: t("description"),
    keywords: t("keywords").split(",").map((k) => k.trim()),
    icons: {
      icon: "/favicon.svg",
      apple: "/icon.svg",
    },
    manifest: "/manifest.json",
    openGraph: {
      title: t("title"),
      description: t("description"),
      type: "website",
      locale: locale === "id" ? "id_ID" : "en_US",
      siteName: "Family Finance",
      images: [{ url: "/og-image.svg", width: 1200, height: 630 }],
    },
    twitter: {
      card: "summary_large_image",
      title: t("title"),
      description: t("description"),
      images: ["/og-image.svg"],
    },
    robots: { index: true, follow: true },
  }
}

export default async function LocaleLayout({
  children,
  params,
}: Props & { children: React.ReactNode }) {
  const { locale } = await params
  if (!hasLocale(locales, locale)) notFound()
  setRequestLocale(locale)
  const messages = await getMessages()

  return (
    <html lang={locale} suppressHydrationWarning className={`${plusJakartaSans.variable} ${geistMono.variable} h-full antialiased`}>
      <body className="min-h-full flex flex-col" style={{ backgroundColor: "var(--bg)", color: "var(--text-primary)" }}>
        <script dangerouslySetInnerHTML={{ __html: themeScript }} />
        <NextIntlClientProvider locale={locale} messages={messages}>
          {children}
        </NextIntlClientProvider>
      </body>
    </html>
  )
}

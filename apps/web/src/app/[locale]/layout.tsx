import type { Metadata } from "next"
import { NextIntlClientProvider } from "next-intl"
import { getMessages, getLocale } from "next-intl/server"

export const metadata: Metadata = {
  title: {
    default: "Family Finance - Kelola Keuangan Keluarga Jadi Lebih Mudah",
    template: "%s | Family Finance",
  },
  description: "Aplikasi keuangan keluarga untuk mencatat pemasukan & pengeluaran, memantau hutang, membuat anggaran, dan mencapai tujuan keuangan bersama keluarga.",
  keywords: ["keuangan keluarga", "family finance", "aplikasi keuangan", "budget keluarga", "manajemen keuangan"],
  icons: {
    icon: "/favicon.svg",
    apple: "/icon.svg",
  },
  manifest: "/manifest.json",
  openGraph: {
    title: "Family Finance - Kelola Keuangan Keluarga Jadi Lebih Mudah",
    description: "Catat pemasukan & pengeluaran, pantau hutang, buat anggaran, capai tujuan keuangan bersama keluarga — semua dalam satu aplikasi.",
    type: "website",
    locale: "id_ID",
    siteName: "Family Finance",
    images: [{ url: "/og-image.svg", width: 1200, height: 630 }],
  },
  twitter: {
    card: "summary_large_image",
    title: "Family Finance - Kelola Keuangan Keluarga",
    description: "Aplikasi keuangan keluarga yang mudah digunakan.",
    images: ["/og-image.svg"],
  },
  robots: { index: true, follow: true },
}

export default async function LocaleLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const locale = await getLocale()
  const messages = await getMessages()

  return (
    <NextIntlClientProvider locale={locale} messages={messages}>
      {children}
    </NextIntlClientProvider>
  )
}

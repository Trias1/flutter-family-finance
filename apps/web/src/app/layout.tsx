import "./globals.css"
import { headers } from "next/headers"
import { getLocale } from "next-intl/server"
import { Geist_Mono, Plus_Jakarta_Sans } from "next/font/google"

// Applies the saved theme before paint, but only inside the dashboard/admin;
// public pages always render light with the default preset.
const themeScript = `(() => { try { if (!/^\\/(en|id)\\/(dashboard|admin)(\\/|$)/.test(location.pathname)) { document.documentElement.dataset.theme = 'light'; document.documentElement.dataset.colorTheme = 'oceanBlue'; document.documentElement.style.colorScheme = 'light'; return; } const key = 'family-finance-theme'; const colorKey = 'family-finance-color-theme'; const stored = localStorage.getItem(key); const mode = stored === 'light' || stored === 'dark' || stored === 'system' ? stored : 'system'; const rawColor = localStorage.getItem(colorKey); const allowed = ['oceanBlue','sage','lavender','charcoalGold','mochaBrown','softPink','roseGold']; const color = allowed.includes(rawColor || '') ? rawColor : 'oceanBlue'; const resolved = mode === 'system' ? (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light') : mode; document.documentElement.dataset.theme = resolved; document.documentElement.dataset.colorTheme = color; document.documentElement.style.colorScheme = resolved; } catch (_) {} })();`

const plusJakartaSans = Plus_Jakarta_Sans({
  variable: "--font-plus-jakarta-sans",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
})

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
})

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const locale = await getLocale()
  const nonce = (await headers()).get("x-nonce") ?? undefined
  return (
    <html lang={locale} suppressHydrationWarning className={`${plusJakartaSans.variable} ${geistMono.variable} h-full antialiased`}>
      <body className="min-h-full flex flex-col" style={{ backgroundColor: "var(--bg)", color: "var(--text-primary)" }}>
        <script nonce={nonce} dangerouslySetInnerHTML={{ __html: themeScript }} />
        {children}
      </body>
    </html>
  )
}


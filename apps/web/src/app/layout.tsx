import "./globals.css"
import { Geist_Mono, Plus_Jakarta_Sans } from "next/font/google"

const themeScript = `(() => { try { const key = 'family-finance-theme'; const colorKey = 'family-finance-color-theme'; const stored = localStorage.getItem(key); const mode = stored === 'light' || stored === 'dark' || stored === 'system' ? stored : 'system'; const color = localStorage.getItem(colorKey) || 'mochaBrown'; const resolved = mode === 'system' ? (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light') : mode; document.documentElement.dataset.theme = resolved; document.documentElement.dataset.colorTheme = color; document.documentElement.style.colorScheme = resolved; } catch (_) {} })();`

const plusJakartaSans = Plus_Jakarta_Sans({
  variable: "--font-plus-jakarta-sans",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
})

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
})

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="id" suppressHydrationWarning className={`${plusJakartaSans.variable} ${geistMono.variable} h-full antialiased`}>
      <body className="min-h-full flex flex-col" style={{ backgroundColor: "var(--bg)", color: "var(--text-primary)" }}>
        <script dangerouslySetInnerHTML={{ __html: themeScript }} />
        {children}
      </body>
    </html>
  )
}

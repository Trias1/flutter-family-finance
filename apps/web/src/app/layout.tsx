import "./globals.css"
import { Geist, Geist_Mono } from "next/font/google"

const themeScript = `(() => { try { const key = 'family-finance-theme'; const stored = localStorage.getItem(key); const mode = stored === 'light' || stored === 'dark' || stored === 'system' ? stored : 'system'; const resolved = mode === 'system' ? (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light') : mode; document.documentElement.dataset.theme = resolved; document.documentElement.style.colorScheme = resolved; } catch (_) {} })();`

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
})

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
})

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="id" suppressHydrationWarning className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}>
      <body className="min-h-full flex flex-col" style={{ backgroundColor: "var(--bg)", color: "var(--text-primary)" }}>
        <script dangerouslySetInnerHTML={{ __html: themeScript }} />
        {children}
      </body>
    </html>
  )
}

"use client"
import "./globals.css"

// Last-resort error page outside the locale layout, so it carries both languages.
export default function Error({ reset }: { error: Error; reset: () => void }) {
  return (
    <html lang="id">
      <body>
        <main className="flex min-h-screen flex-col items-center justify-center px-6 text-center" style={{ backgroundColor: "var(--bg)", color: "var(--text-primary)" }}>
          <h1 className="text-2xl font-semibold">Terjadi kesalahan · Something went wrong</h1>
          <p className="mt-2 max-w-md text-sm" style={{ color: "var(--text-secondary)" }}>
            Muat ulang halaman atau coba lagi. · Reload the page or try again.
          </p>
          <button type="button" onClick={reset} className="auth-btn-primary mt-6 !w-auto px-5">Coba lagi · Try again</button>
        </main>
      </body>
    </html>
  )
}

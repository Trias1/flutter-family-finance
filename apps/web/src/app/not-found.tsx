import Link from "next/link"

// Fallback outside the locale layout, so it carries both languages.
export default function NotFound() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center px-6 text-center" style={{ backgroundColor: "var(--bg)", color: "var(--text-primary)" }}>
      <p className="text-sm font-medium tabular-nums" style={{ color: "var(--text-muted)" }}>404</p>
      <h1 className="mt-2 text-2xl font-semibold">Halaman tidak ditemukan · Page not found</h1>
      <Link href="/" className="auth-btn-primary mt-6 !w-auto px-5">Beranda · Home</Link>
    </main>
  )
}

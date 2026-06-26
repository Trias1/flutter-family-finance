import Link from "next/link"

export default function NotFound() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center px-6 text-center" style={{ backgroundColor: "var(--bg)", color: "var(--text-primary)" }}>
      <div className="flex h-20 w-20 items-center justify-center rounded-2xl text-3xl" style={{ backgroundColor: "var(--primary-bg)" }}>📱</div>
      <h1 className="mt-6 text-6xl font-bold" style={{ color: "var(--primary)" }}>404</h1>
      <h2 className="mt-2 text-xl font-semibold">Halaman Tidak Ditemukan</h2>
      <p className="mt-2 max-w-md" style={{ color: "var(--text-secondary)" }}>Halaman yang kamu cari tidak ada atau telah dipindahkan.</p>
      <Link
        href="/"
        className="mt-8 inline-flex items-center gap-2 rounded-xl px-6 py-3 text-sm font-medium text-white transition-all hover:shadow-lg"
        style={{ backgroundColor: "var(--primary)" }}
      >
        Kembali ke Beranda
      </Link>
    </div>
  )
}

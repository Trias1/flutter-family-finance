"use client"

export default function Error({ error, reset }: { error: Error; reset: () => void }) {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center px-6 text-center" style={{ backgroundColor: "var(--bg)", color: "var(--text-primary)" }}>
      <div className="flex h-20 w-20 items-center justify-center rounded-2xl text-3xl" style={{ backgroundColor: "var(--expense-bg)" }}>⚠️</div>
      <h1 className="mt-6 text-xl font-semibold">Terjadi Kesalahan</h1>
      <p className="mt-2 max-w-md text-sm" style={{ color: "var(--text-secondary)" }}>{error.message || "Terjadi kesalahan yang tidak terduga."}</p>
      <button
        onClick={reset}
        className="mt-8 inline-flex items-center gap-2 rounded-xl px-6 py-3 text-sm font-medium text-white transition-all hover:shadow-lg"
        style={{ backgroundColor: "var(--primary)" }}
      >
        Coba Lagi
      </button>
    </div>
  )
}

import Link from "next/link"

export default async function OpenAiAuthCallbackPage({ searchParams }: { searchParams: Promise<{ code?: string; state?: string; error?: string; error_description?: string }> }) {
  const params = await searchParams
  const hasCode = Boolean(params.code)

  return (
    <main className="banking-page-bg flex min-h-screen items-center justify-center px-6 py-12">
      <section className="w-full max-w-xl rounded-[2rem] p-8 text-center glass-card">
        <p className="text-sm font-bold uppercase tracking-[0.22em]" style={{ color: "var(--primary)" }}>OpenAI Login Callback</p>
        <h1 className="mt-4 text-3xl font-black tracking-[-0.04em]" style={{ color: "var(--text-primary)" }}>
          {hasCode ? "Login OpenAI berhasil diarahkan ke localhost:3000" : "Callback OpenAI diterima"}
        </h1>
        <p className="mt-4 text-sm leading-6" style={{ color: "var(--text-secondary)" }}>
          {params.error ? params.error_description || params.error : "Kode OAuth sudah diterima di halaman ini. Untuk fitur AI production, tetap gunakan OPENAI_API_KEY di Vercel/server."}
        </p>
        {hasCode && (
          <div className="mt-5 rounded-2xl p-4 text-left" style={{ backgroundColor: "var(--surface-soft)" }}>
            <p className="text-xs font-bold uppercase tracking-[0.16em]" style={{ color: "var(--text-muted)" }}>Authorization code</p>
            <code className="mt-2 block break-all text-xs" style={{ color: "var(--text-secondary)" }}>{params.code}</code>
          </div>
        )}
        <Link href="/admin/ai" className="mt-6 inline-flex rounded-2xl px-5 py-3 text-sm font-black text-white" style={{ backgroundColor: "var(--primary)" }}>
          Kembali ke AI Center
        </Link>
      </section>
    </main>
  )
}

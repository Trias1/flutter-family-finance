"use client"

import { useEffect, useMemo, useState } from "react"
import { onAuthStateChanged } from "firebase/auth"
import { Bot, CheckCircle2, ExternalLink, KeyRound, Layers3, ShieldCheck, Sparkles, WandSparkles } from "lucide-react"

import AdminShell from "@/components/AdminShell"
import { auth, db } from "@/lib/firebase"
import { doc, getDoc } from "firebase/firestore"

type ProviderStatus = {
  id: string
  name: string
  model: string
  status: "default" | "ready" | "planned"
  description: string
}

const providers: ProviderStatus[] = [
  {
    id: "openai",
    name: "OpenAI / ChatGPT",
    model: "Primary provider",
    status: "default",
    description: "Provider utama untuk generate insight finansial dari server admin.",
  },
  {
    id: "gemini",
    name: "Google Gemini",
    model: "Optional adapter",
    status: "planned",
    description: "Disiapkan sebagai opsi/fallback setelah environment key dipasang di server.",
  },
  {
    id: "groq",
    name: "Groq",
    model: "Optional adapter",
    status: "planned",
    description: "Disiapkan untuk model cepat dan murah, tanpa key di mobile app.",
  },
]

function ProviderBadge({ status }: { status: ProviderStatus["status"] }) {
  const label = status === "default" ? "Default" : status === "ready" ? "Ready" : "Planned"
  const color = status === "default" ? "var(--primary)" : status === "ready" ? "var(--income)" : "var(--text-muted)"
  return (
    <span className="rounded-full px-3 py-1 text-xs font-bold" style={{ backgroundColor: "var(--primary-bg)", color }}>
      {label}
    </span>
  )
}

export default function AdminAiPage() {
  const [authorized, setAuthorized] = useState(false)
  const [loading, setLoading] = useState(true)
  const [currentUser, setCurrentUser] = useState<import("firebase/auth").User | null>(null)
  const [testMessage, setTestMessage] = useState("Kasih ringkasan singkat kondisi keuangan bulan ini")
  const [testResult, setTestResult] = useState("")
  const [testBusy, setTestBusy] = useState(false)

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (user) => {
      if (!user) {
        setCurrentUser(null)
        setAuthorized(false)
        setLoading(false)
        return
      }

      setCurrentUser(user)
      const snap = await getDoc(doc(db, "users", user.uid))
      setAuthorized(snap.data()?.systemRole === "superadmin")
      setLoading(false)
    })

    return () => unsub()
  }, [])

  const activeProvider = useMemo(() => providers.find((provider) => provider.status === "default"), [])

  const testOpenAiConnection = async () => {
    if (!currentUser || !testMessage.trim()) return
    setTestBusy(true)
    setTestResult("")
    try {
      const token = await currentUser.getIdToken()
      const res = await fetch("/api/ai/chat", {
        method: "POST",
        headers: {
          authorization: `Bearer ${token}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({ message: testMessage }),
      })
      const json = await res.json().catch(() => ({}))
      setTestResult(json.reply || json.error || "Tidak ada respons dari AI.")
    } catch (error) {
      setTestResult(error instanceof Error ? error.message : "Gagal menghubungi AI.")
    } finally {
      setTestBusy(false)
    }
  }

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center" style={{ backgroundColor: "var(--bg)", color: "var(--text-primary)" }}>
        <div className="h-10 w-10 animate-spin rounded-full border-4 border-t-transparent" style={{ borderColor: "var(--primary)", borderTopColor: "transparent" }} />
      </div>
    )
  }

  if (!authorized) {
    return (
      <div className="flex min-h-screen items-center justify-center p-6" style={{ backgroundColor: "var(--bg)", color: "var(--text-primary)" }}>
        <div className="max-w-md rounded-3xl border p-8 text-center" style={{ backgroundColor: "color-mix(in srgb, var(--bg-card) 78%, transparent)", borderColor: "rgba(255,255,255,0.62)", boxShadow: "var(--shadow-soft)", backdropFilter: "blur(22px)" }}>
          <ShieldCheck className="mx-auto mb-4" style={{ color: "var(--expense)" }} />
          <h1 className="text-2xl font-bold">Akses Super Admin Dibutuhkan</h1>
          <p className="mt-2 text-sm" style={{ color: "var(--text-secondary)" }}>Halaman AI hanya tersedia untuk akun super admin.</p>
        </div>
      </div>
    )
  }

  return (
    <AdminShell user={currentUser}>
      <div className="space-y-6">
        <section className="overflow-hidden rounded-[2rem] border p-6 lg:p-8" style={{ background: "linear-gradient(135deg, var(--primary-bg), var(--bg-card) 55%, var(--surface-soft))", borderColor: "var(--border)" }}>
          <div className="grid gap-6 lg:grid-cols-[1.3fr_0.7fr] lg:items-center">
            <div>
              <div className="mb-4 inline-flex items-center gap-2 rounded-full px-4 py-2 text-fluid-sm font-bold" style={{ backgroundColor: "var(--bg-card)", color: "var(--primary)" }}>
                <Sparkles size={16} /> Super Admin AI Center
              </div>
              <h1 className="max-w-3xl responsive-section-title font-black" style={{ color: "var(--text-primary)" }}>
                Generate AI dari web admin, hasilnya dikirim aman ke HP user.
              </h1>
              <p className="mt-4 max-w-2xl responsive-copy" style={{ color: "var(--text-secondary)" }}>
                Mobile app tidak menyimpan API key dan tidak memanggil provider AI langsung. Semua provider berjalan di server admin, lalu hasilnya nanti disimpan ke Firestore dan dikirim via FCM.
              </p>
            </div>
            <div className="rounded-3xl border p-5" style={{ backgroundColor: "color-mix(in srgb, var(--bg-card) 78%, transparent)", borderColor: "rgba(255,255,255,0.62)", boxShadow: "var(--shadow-soft)", backdropFilter: "blur(22px)" }}>
              <div className="flex items-center gap-3">
                <span className="flex h-12 w-12 items-center justify-center rounded-2xl text-white" style={{ backgroundColor: "var(--primary)" }}>
                  <Bot size={22} />
                </span>
                <div>
                  <p className="text-xs uppercase tracking-[0.24em]" style={{ color: "var(--text-muted)" }}>Active default</p>
                  <p className="text-lg font-bold" style={{ color: "var(--text-primary)" }}>{activeProvider?.name}</p>
                </div>
              </div>
              <div className="mt-5 rounded-2xl p-4" style={{ backgroundColor: "var(--surface-soft)" }}>
                <p className="text-sm font-semibold" style={{ color: "var(--text-primary)" }}>Key status</p>
                <p className="mt-1 text-xs leading-5" style={{ color: "var(--text-secondary)" }}>Login ke OpenAI dashboard untuk buat API key, lalu simpan key itu di environment Vercel/server. Key tidak ditaruh di repo atau client.</p>
              </div>
            </div>
          </div>
        </section>


        <section className="rounded-[2rem] p-6 glass-card">
          <div className="grid gap-5 lg:grid-cols-[0.9fr_1.1fr] lg:items-start">
            <div>
              <p className="text-fluid-sm font-bold uppercase tracking-[0.22em]" style={{ color: "var(--primary)" }}>OpenAI connection test</p>
              <h2 className="mt-3 text-2xl font-black" style={{ color: "var(--text-primary)" }}>Cek koneksi AI dari server admin</h2>
              <p className="mt-3 text-fluid-sm leading-6" style={{ color: "var(--text-secondary)" }}>
                Login OpenAI/ChatGPT dilakukan di dashboard OpenAI untuk membuat API key. Tombol ChatGPT membuka auth.openai.com untuk login akun OpenAI bg. Untuk AI aplikasi production tetap pakai OPENAI_API_KEY di server agar aman.
              </p>
              <div className="mt-4 rounded-2xl p-4" style={{ backgroundColor: "var(--surface-soft)" }}>
                <p className="text-xs font-bold" style={{ color: "var(--text-muted)" }}>Required env</p>
                <code className="mt-2 block text-fluid-sm font-bold" style={{ color: "var(--text-primary)" }}>OPENAI_API_KEY</code>
                <code className="mt-1 block text-xs" style={{ color: "var(--text-secondary)" }}>OPENAI_MODEL optional, default gpt-4.1-mini</code>
              </div>
              <div className="mt-4 flex flex-col gap-3 sm:flex-row">
                <a
                  href="https://auth.openai.com/oauth/authorize?response_type=code&client_id=app_EMoamEEZ73f0CkXaXp7hrann&redirect_uri=http%3A%2F%2Flocalhost%3A3000%2Fauth%2Fcallback&scope=openid%20profile%20email%20offline_access&code_challenge=NHXGYbPPkMTt-DhjZdn792Z4vow2T4pX3aSu5h_6K_Q&code_challenge_method=S256&id_token_add_organizations=true&codex_cli_simplified_flow=true&originator=codex_cli_rs&state=KbLJqrzkthoMYwYL7FQNi6HuE-JqPAWIxHwcsa8Wn_8"
                  target="_blank"
                  rel="noreferrer"
                  className="inline-flex items-center justify-center gap-2 rounded-2xl px-4 py-3 text-sm font-black text-white transition-transform hover:-translate-y-0.5"
                  style={{ backgroundColor: "var(--primary)" }}
                >
                  Login ChatGPT <ExternalLink size={16} />
                </a>
                <a
                  href="https://platform.openai.com/api-keys"
                  target="_blank"
                  rel="noreferrer"
                  className="inline-flex items-center justify-center gap-2 rounded-2xl px-4 py-3 text-sm font-black glass-card"
                  style={{ color: "var(--primary)" }}
                >
                  Buat API Key <ExternalLink size={16} />
                </a>
              </div>
            </div>
            <div className="space-y-3">
              <textarea
                value={testMessage}
                onChange={(event) => setTestMessage(event.target.value)}
                className="min-h-28 w-full rounded-2xl border bg-white/60 p-4 text-sm outline-none focus:border-blue-400"
                style={{ borderColor: "var(--border)", color: "var(--text-primary)" }}
              />
              <button
                type="button"
                onClick={testOpenAiConnection}
                disabled={testBusy}
                className="rounded-2xl px-5 py-3 text-fluid-sm font-black text-white transition-transform hover:-translate-y-0.5 disabled:cursor-not-allowed disabled:opacity-60"
                style={{ backgroundColor: "var(--primary)" }}
              >
                {testBusy ? "Testing..." : "Test OpenAI"}
              </button>
              {testResult && (
                <div className="rounded-2xl p-4 text-fluid-sm leading-6" style={{ backgroundColor: "var(--surface-soft)", color: "var(--text-secondary)" }}>
                  {testResult}
                </div>
              )}
            </div>
          </div>
        </section>
        <section className="grid gap-4 md:grid-cols-3">
          {providers.map((provider) => (
            <div key={provider.id} className="rounded-3xl border p-5" style={{ backgroundColor: "color-mix(in srgb, var(--bg-card) 78%, transparent)", borderColor: "rgba(255,255,255,0.62)", boxShadow: "var(--shadow-soft)", backdropFilter: "blur(22px)" }}>
              <div className="mb-4 flex items-center justify-between gap-3">
                <span className="flex h-11 w-11 items-center justify-center rounded-2xl" style={{ backgroundColor: "var(--primary-bg)", color: "var(--primary)" }}>
                  <Layers3 size={19} />
                </span>
                <ProviderBadge status={provider.status} />
              </div>
              <h2 className="text-lg font-bold" style={{ color: "var(--text-primary)" }}>{provider.name}</h2>
              <p className="mt-1 text-xs font-semibold uppercase tracking-[0.18em]" style={{ color: "var(--text-muted)" }}>{provider.model}</p>
              <p className="mt-3 text-fluid-sm leading-6" style={{ color: "var(--text-secondary)" }}>{provider.description}</p>
            </div>
          ))}
        </section>

        <section className="grid gap-4 lg:grid-cols-3">
          <div className="rounded-3xl border p-5" style={{ backgroundColor: "color-mix(in srgb, var(--bg-card) 78%, transparent)", borderColor: "rgba(255,255,255,0.62)", boxShadow: "var(--shadow-soft)", backdropFilter: "blur(22px)" }}>
            <KeyRound className="mb-4" style={{ color: "var(--primary)" }} />
            <h3 className="font-bold" style={{ color: "var(--text-primary)" }}>No client key</h3>
            <p className="mt-2 text-fluid-sm leading-6" style={{ color: "var(--text-secondary)" }}>API key AI tidak ditaruh di Flutter, browser client, atau Firestore.</p>
          </div>
          <div className="rounded-3xl border p-5" style={{ backgroundColor: "color-mix(in srgb, var(--bg-card) 78%, transparent)", borderColor: "rgba(255,255,255,0.62)", boxShadow: "var(--shadow-soft)", backdropFilter: "blur(22px)" }}>
            <WandSparkles className="mb-4" style={{ color: "var(--primary)" }} />
            <h3 className="font-bold" style={{ color: "var(--text-primary)" }}>Adapter ready</h3>
            <p className="mt-2 text-fluid-sm leading-6" style={{ color: "var(--text-secondary)" }}>Struktur provider nanti bisa dipakai untuk OpenAI, Gemini, dan Groq tanpa ubah mobile app.</p>
          </div>
          <div className="rounded-3xl border p-5" style={{ backgroundColor: "color-mix(in srgb, var(--bg-card) 78%, transparent)", borderColor: "rgba(255,255,255,0.62)", boxShadow: "var(--shadow-soft)", backdropFilter: "blur(22px)" }}>
            <CheckCircle2 className="mb-4" style={{ color: "var(--income)" }} />
            <h3 className="font-bold" style={{ color: "var(--text-primary)" }}>Next step aman</h3>
            <p className="mt-2 text-fluid-sm leading-6" style={{ color: "var(--text-secondary)" }}>Test koneksi aktif setelah OPENAI_API_KEY dipasang di Vercel/server.</p>
          </div>
        </section>
      </div>
    </AdminShell>
  )
}









import AppPhonePreview from "@/components/public/AppPhonePreview"

export default function AppThemedBackground({ compact = false }: { compact?: boolean }) {
  return (
    <div className="absolute inset-0 overflow-hidden bg-[#050505]">
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_top,_rgba(102,187,106,0.22),_transparent_34%),radial-gradient(circle_at_80%_25%,_rgba(66,165,245,0.14),_transparent_28%),linear-gradient(180deg,_#0B1020_0%,_#050505_60%,_#050505_100%)]" />
      <div className="absolute inset-0 bg-[linear-gradient(135deg,rgba(255,255,255,0.02)_0%,transparent_40%,rgba(102,187,106,0.05)_100%)]" />

      <div className="animate-drift-slow absolute -left-16 top-24 h-72 w-72 rounded-full bg-[#2E7D32]/20 blur-3xl" />
      <div className="animate-drift-medium absolute bottom-16 right-0 h-80 w-80 rounded-full bg-[#66BB6A]/15 blur-3xl" />
      <div className="animate-pulse-soft absolute left-1/2 top-1/2 h-[440px] w-[440px] -translate-x-1/2 -translate-y-1/2 rounded-full border border-white/5" />
      <div className="animate-pulse-soft absolute left-1/2 top-1/2 h-[620px] w-[620px] -translate-x-1/2 -translate-y-1/2 rounded-full border border-white/[0.04]" style={{ animationDelay: "0.8s" }} />

      {!compact && (
        <>
          <AppPhonePreview variant="wallets" className="animate-phone-float-slow absolute left-[8%] top-[18%] hidden xl:block" style={{ ["--phone-rotate" as string]: "-14deg" }} />
          <AppPhonePreview variant="dashboard" className="animate-phone-float-soft absolute left-1/2 top-[14%] -translate-x-1/2" style={{ ["--phone-rotate" as string]: "-4deg" }} />
          <AppPhonePreview variant="reports" className="animate-phone-float-slow absolute right-[9%] top-[24%] hidden xl:block" style={{ ["--phone-rotate" as string]: "12deg" }} />
        </>
      )}

      <div className="absolute bottom-0 left-0 right-0 h-64 bg-gradient-to-t from-black via-black/55 to-transparent" />
    </div>
  )
}

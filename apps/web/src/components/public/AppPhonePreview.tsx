import type { CSSProperties } from "react"

export default function AppPhonePreview({ variant = "dashboard", className = "", style }: { variant?: "dashboard" | "wallets" | "reports"; className?: string; style?: CSSProperties }) {
  return (
    <div style={style} className={`animate-screen-glow relative h-[360px] w-[178px] rounded-[2rem] border border-white/15 bg-[#0E1628]/90 p-2 shadow-[0_30px_80px_rgba(0,0,0,0.35)] backdrop-blur-md ${className}`}>
      <div className="absolute left-1/2 top-0 z-10 h-5 w-24 -translate-x-1/2 rounded-b-2xl bg-[#05070D]" />
      <div className="h-full overflow-hidden rounded-[1.5rem] bg-[#F5F6FA] pt-6">
        <div className="flex items-center justify-between px-3 text-[9px] font-semibold text-gray-500">
          <span>9:41</span>
          <span>100%</span>
        </div>
        <div className="animate-screen-scroll-loop">
          {variant === "dashboard" && <DashboardScreen />}
          {variant === "wallets" && <WalletScreen />}
          {variant === "reports" && <ReportsScreen />}
        </div>
      </div>
    </div>
  )
}

function DashboardScreen() {
  return (
    <div className="px-3 pt-3">
      <div className="rounded-2xl bg-gradient-to-br from-[#2E7D32] to-[#66BB6A] p-4 text-white">
        <p className="text-[10px] text-white/80">Total Saldo</p>
        <p className="mt-1 text-lg font-bold">Rp12.500.000</p>
        <div className="mt-3 flex gap-3 text-[10px] text-white/80">
          <span>+ 5.0jt</span>
          <span>- 3.2jt</span>
        </div>
      </div>
      <div className="mt-3 grid grid-cols-4 gap-2 text-center text-[9px] text-gray-500">
        {["Dompet", "Masuk", "Keluar", "Laporan"].map((item) => (
          <div key={item} className="rounded-xl bg-white px-1 py-2 shadow-sm">
            <div className="mx-auto mb-1 h-7 w-7 rounded-lg bg-[#E8F5E9]" />
            {item}
          </div>
        ))}
      </div>
      <div className="mt-4 space-y-2">
        {[
          ["Belanja", "-Rp250.000", "#EF5350"],
          ["Gaji", "+Rp5.000.000", "#4CAF50"],
          ["Listrik", "-Rp150.000", "#EF5350"],
          ["Air", "-Rp95.000", "#EF5350"],
          ["Bonus", "+Rp750.000", "#4CAF50"],
        ].map(([label, amount, color]) => (
          <div key={label} className="flex items-center justify-between rounded-xl bg-white px-3 py-2 shadow-sm">
            <span className="text-[11px] font-medium text-[#1B1B1F]">{label}</span>
            <span className="text-[10px] font-semibold" style={{ color }}>{amount}</span>
          </div>
        ))}
      </div>
    </div>
  )
}

function WalletScreen() {
  return (
    <div className="px-3 pt-3">
      <div className="flex items-center justify-between">
        <p className="text-sm font-semibold text-[#1B1B1F]">Dompet Saya</p>
        <span className="text-[10px] font-medium text-[#2E7D32]">+ Tambah</span>
      </div>
      <div className="mt-3 space-y-2">
        {[
          ["Tunai", "Rp2.000.000"],
          ["BCA", "Rp3.200.000"],
          ["GoPay", "Rp500.000"],
        ].map(([name, amount]) => (
          <div key={name} className="flex items-center justify-between rounded-xl bg-white px-3 py-3 shadow-sm">
            <div>
              <p className="text-[11px] font-semibold text-[#1B1B1F]">{name}</p>
              <p className="text-[10px] text-gray-400">{amount}</p>
            </div>
            <div className="h-8 w-8 rounded-lg bg-[#E8F5E9]" />
          </div>
        ))}
      </div>
      <div className="mt-4 rounded-2xl bg-white p-3 shadow-sm">
        <p className="text-[10px] font-semibold text-[#1B1B1F]">Transfer Antar Dompet</p>
        <div className="mt-3 h-2 rounded-full bg-gray-100">
          <div className="h-2 w-2/3 rounded-full bg-[#66BB6A]" />
        </div>
      </div>
      <div className="mt-3 rounded-2xl bg-white p-3 shadow-sm">
        <p className="text-[10px] font-semibold text-[#1B1B1F]">Aktivitas Terakhir</p>
        <div className="mt-2 space-y-2 text-[10px] text-gray-500">
          <div className="flex items-center justify-between"><span>Top up GoPay</span><span>2m</span></div>
          <div className="flex items-center justify-between"><span>Transfer BCA</span><span>14m</span></div>
        </div>
      </div>
    </div>
  )
}

function ReportsScreen() {
  return (
    <div className="px-3 pt-3">
      <p className="text-sm font-semibold text-[#1B1B1F]">Laporan Bulanan</p>
      <div className="mt-3 rounded-2xl bg-white p-3 shadow-sm">
        <div className="grid grid-cols-3 gap-2 text-center">
          {[
            ["Masuk", "8.5jt", "#4CAF50"],
            ["Keluar", "3.2jt", "#EF5350"],
            ["Sisa", "5.3jt", "#2E7D32"],
          ].map(([label, value, color]) => (
            <div key={label} className="rounded-xl bg-[#F8FAFC] p-2">
              <p className="text-[9px] text-gray-400">{label}</p>
              <p className="mt-1 text-[10px] font-bold" style={{ color }}>{value}</p>
            </div>
          ))}
        </div>
        <div className="mt-4 h-20 rounded-2xl bg-gradient-to-t from-[#E8F5E9] to-white p-3">
          <div className="flex h-full items-end justify-between gap-1">
            {[32, 55, 40, 78, 62, 84].map((height, index) => (
              <div key={index} className="w-full rounded-t-md bg-[#2E7D32]/85" style={{ height }} />
            ))}
          </div>
        </div>
      </div>
      <div className="mt-3 rounded-2xl bg-white p-3 shadow-sm">
        <div className="flex items-center justify-between text-[10px]">
          <span className="font-semibold text-[#1B1B1F]">Kategori</span>
          <span className="text-gray-400">bulan ini</span>
        </div>
        <div className="mt-3 space-y-2">
          {[
            ["Makanan", "40%"],
            ["Transport", "25%"],
            ["Tagihan", "18%"],
          ].map(([label, value]) => (
            <div key={label} className="flex items-center justify-between text-[10px] text-gray-500"><span>{label}</span><span>{value}</span></div>
          ))}
        </div>
      </div>
    </div>
  )
}

const full = new Intl.NumberFormat("id-ID", { maximumFractionDigits: 0 })

/** Rp1.250.000, or −Rp1.250.000 for negatives. */
export function formatRupiah(value: number) {
  const rounded = Math.round(value)
  return `${rounded < 0 ? "−" : ""}Rp${full.format(Math.abs(rounded))}`
}

/** Short form for chart axes: "1,2 jt" / "850 rb" in Indonesian, "1.2M" / "850K" in English. */
export function formatCompact(value: number, locale = "id") {
  if (locale !== "id") {
    return new Intl.NumberFormat("en", { notation: "compact", maximumFractionDigits: 1 }).format(value)
  }
  const abs = Math.abs(value)
  if (abs >= 1_000_000_000) return `${(value / 1_000_000_000).toLocaleString("id-ID", { maximumFractionDigits: 1 })} M`
  if (abs >= 1_000_000) return `${(value / 1_000_000).toLocaleString("id-ID", { maximumFractionDigits: 1 })} jt`
  if (abs >= 1_000) return `${Math.round(value / 1_000).toLocaleString("id-ID")} rb`
  return `${Math.round(value)}`
}

export function monthKey(date: Date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}`
}

export function startOfMonth(date: Date, offset = 0) {
  return new Date(date.getFullYear(), date.getMonth() + offset, 1)
}

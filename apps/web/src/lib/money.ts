const full = new Intl.NumberFormat("id-ID", { maximumFractionDigits: 0 })

// The family's (or personal) currency, set by FamilyDataProvider from the
// same Firestore field the Android app writes. Amounts are stored as plain
// numbers, so this only changes how they are shown.
const SUPPORTED = ["IDR", "USD", "EUR", "GBP", "JPY", "SGD", "MYR", "SAR"]
let displayCurrency = "IDR"
const formatters = new Map<string, Intl.NumberFormat>()

export function setDisplayCurrency(code: string | null | undefined) {
  displayCurrency = code && SUPPORTED.includes(code) ? code : "IDR"
}

/** Rp1.250.000 (or $1,250.00 etc. for other currencies); − for negatives. */
export function formatRupiah(value: number) {
  if (displayCurrency === "IDR") {
    const rounded = Math.round(value)
    return `${rounded < 0 ? "−" : ""}Rp${full.format(Math.abs(rounded))}`
  }
  let fmt = formatters.get(displayCurrency)
  if (!fmt) {
    fmt = new Intl.NumberFormat("en-US", { style: "currency", currency: displayCurrency })
    formatters.set(displayCurrency, fmt)
  }
  return `${value < 0 ? "−" : ""}${fmt.format(Math.abs(value))}`
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

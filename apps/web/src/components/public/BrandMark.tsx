// Ledger-style mark: two rows of a balance and a tick. Colors follow the
// active preset so the logo matches the rest of the page.
export default function BrandMark({ size = 22 }: { size?: number; dark?: boolean }) {
  return (
    <svg width={size} height={size} viewBox="0 0 22 22" fill="none" aria-hidden="true">
      <rect x="1" y="1" width="20" height="20" rx="4" style={{ fill: "var(--primary)" }} />
      <rect x="5" y="7" width="12" height="2" rx="1" fill="#fff" />
      <rect x="5" y="13" width="7" height="2" rx="1" fill="#fff" fillOpacity="0.7" />
      <rect x="14" y="12" width="3" height="4" rx="1" style={{ fill: "var(--accent)" }} />
    </svg>
  )
}

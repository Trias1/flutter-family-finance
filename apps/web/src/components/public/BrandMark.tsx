export default function BrandMark({ dark = false }: { dark?: boolean }) {
  return (
    <svg width="22" height="22" viewBox="0 0 22 22" fill="none" aria-hidden="true">
      <path d="M3 11.5 10.8 3l2.8 3-7.8 8.5L3 11.5Z" fill={dark ? "#111111" : "#ffffff"} fillOpacity="0.96" />
      <path d="M11.5 19 8 15.2l6.9-7.7 3.5 3.8L11.5 19Z" fill="#66BB6A" />
      <path d="M13.4 6 16.2 3l2.8 3-2.8 3L13.4 6Z" fill="#A7F3D0" />
    </svg>
  )
}

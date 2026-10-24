// The real root (<html>, fonts, theme) is src/app/[locale]/layout.tsx, where
// the locale comes from the URL so pages can be prerendered. Pages outside a
// locale (not-found, error) render their own <html>.
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return children
}

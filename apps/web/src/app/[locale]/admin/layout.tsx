// Rendered per request so Next can stamp its scripts with the CSP nonce
// (src/proxy.ts); the public pages are prerendered instead.
export const dynamic = "force-dynamic"

export default function Layout({ children }: { children: React.ReactNode }) {
  return children
}

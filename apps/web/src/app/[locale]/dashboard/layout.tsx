import type { ReactNode } from "react"

import DashboardShell from "@/components/DashboardShell"

// Rendered per request so Next can stamp its scripts with the CSP nonce
// (src/proxy.ts); the public pages are prerendered instead.
export const dynamic = "force-dynamic"

export default function DashboardLayout({ children }: { children: ReactNode }) {
  return <DashboardShell>{children}</DashboardShell>
}

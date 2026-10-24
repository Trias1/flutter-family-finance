// Uptime check for monitors: answers at once, touches no database.
export const dynamic = "force-dynamic"

export function GET() {
  return Response.json(
    { ok: true, service: "family-finance-web", time: new Date().toISOString() },
    { headers: { "Cache-Control": "no-store" } },
  )
}

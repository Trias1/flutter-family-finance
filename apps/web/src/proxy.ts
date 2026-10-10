import { NextRequest } from "next/server"
import createMiddleware from "next-intl/middleware"

const intl = createMiddleware({
  locales: ["en", "id"],
  defaultLocale: "en",
  localeDetection: true,
  localePrefix: "always",
})

const isDev = process.env.NODE_ENV !== "production"

// Scripts run only with this request's nonce ('strict-dynamic' lets them load
// Firebase's Google sign-in helpers). Inline style attributes are still
// allowed because components set colors through CSS variables.
function contentSecurityPolicy(nonce: string) {
  return [
    "default-src 'self'",
    `script-src 'self' 'nonce-${nonce}' 'strict-dynamic' https://apis.google.com${isDev ? " 'unsafe-eval'" : ""}`,
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data: blob: https://lh3.googleusercontent.com",
    "font-src 'self' data:",
    `connect-src 'self' https://*.googleapis.com https://*.firebaseio.com wss://*.firebaseio.com https://firebaseinstallations.googleapis.com${isDev ? " ws://localhost:*" : ""}`,
    "frame-src https://tabunganapps.firebaseapp.com https://accounts.google.com https://apis.google.com",
    "worker-src 'self' blob:",
    "object-src 'none'",
    "base-uri 'self'",
    "form-action 'self'",
    "frame-ancestors 'none'",
    ...(isDev ? [] : ["upgrade-insecure-requests"]),
  ].join("; ")
}

export default function proxy(request: NextRequest) {
  const nonce = Buffer.from(crypto.randomUUID()).toString("base64")
  const csp = contentSecurityPolicy(nonce)

  // Next reads the nonce from the request's CSP header and applies it to its
  // own scripts; the layout reads x-nonce for the inline theme script.
  const headers = new Headers(request.headers)
  headers.set("x-nonce", nonce)
  headers.set("Content-Security-Policy", csp)

  const response = intl(new NextRequest(request, { headers }))
  response.headers.set("Content-Security-Policy", csp)
  return response
}

export const config = {
  matcher: ["/((?!api|_next|_vercel|.*\\..*).*)"],
}

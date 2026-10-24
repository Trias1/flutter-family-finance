import { NextRequest } from "next/server"
import createMiddleware from "next-intl/middleware"
import { themeScript } from "@/lib/theme-script"

const intl = createMiddleware({
  locales: ["en", "id"],
  defaultLocale: "en",
  localeDetection: true,
  localePrefix: "always",
})

const isDev = process.env.NODE_ENV !== "production"

// Pages that handle accounts and money render per request and get a nonce.
// Everything else (landing, guide, 404) is prerendered, so it cannot carry a
// per-request nonce and uses the static policy below.
const appRoute = /^\/(en|id)\/(login|dashboard|admin)(\/|$)/

let themeHash: Promise<string> | null = null
function themeScriptHash() {
  themeHash ??= crypto.subtle
    .digest("SHA-256", new TextEncoder().encode(themeScript))
    .then((buf) => `'sha256-${Buffer.from(buf).toString("base64")}'`)
  return themeHash
}

function policy(scriptSrc: string) {
  return [
    "default-src 'self'",
    `script-src ${scriptSrc}${isDev ? " 'unsafe-eval'" : ""}`,
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

// Scripts run only with this request's nonce ('strict-dynamic' lets them load
// Firebase's Google sign-in helpers); the inline theme script by its hash.
// Inline style attributes are still allowed because components set colors
// through CSS variables.
async function appPolicy(nonce: string) {
  return policy(`'self' 'nonce-${nonce}' ${await themeScriptHash()} 'strict-dynamic' https://apis.google.com`)
}

// Prerendered pages: their scripts and inline bootstrap come from this
// origin's build; no user data is on these pages.
const publicPolicy = policy("'self' 'unsafe-inline' https://apis.google.com")

export default async function proxy(request: NextRequest) {
  if (!appRoute.test(request.nextUrl.pathname)) {
    const response = intl(request)
    response.headers.set("Content-Security-Policy", publicPolicy)
    return response
  }

  const nonce = Buffer.from(crypto.randomUUID()).toString("base64")
  const csp = await appPolicy(nonce)

  // Next reads the nonce from the request's CSP header and applies it to its
  // own scripts.
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

"use client"

import { useEffect } from "react"

/**
 * Public pages (home, guide, sign-in) always use the light default look; the
 * user's theme and color preset apply only inside the dashboard and admin.
 * This also resets the page after a client-side move out of the dashboard.
 */
export default function PublicTheme() {
  useEffect(() => {
    const root = document.documentElement
    root.dataset.theme = "light"
    root.dataset.colorTheme = "oceanBlue"
    root.style.colorScheme = "light"
  }, [])
  return null
}

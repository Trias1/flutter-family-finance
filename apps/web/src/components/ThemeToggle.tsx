"use client"

import { useEffect, useState } from "react"

import { applyTheme, readStoredTheme, setStoredTheme, ThemeMode } from "@/lib/theme"

const modes: ThemeMode[] = ["system", "light", "dark"]

export default function ThemeToggle() {
  const [mode, setMode] = useState<ThemeMode>("system")

  useEffect(() => {
    const stored = readStoredTheme()
    setMode(stored)
    applyTheme(stored)

    const media = window.matchMedia("(prefers-color-scheme: dark)")
    const handleChange = () => {
      if (readStoredTheme() === "system") applyTheme("system")
    }
    media.addEventListener("change", handleChange)
    return () => media.removeEventListener("change", handleChange)
  }, [])

  const cycleTheme = () => {
    const next = modes[(modes.indexOf(mode) + 1) % modes.length]
    setMode(next)
    setStoredTheme(next)
    applyTheme(next)
  }

  const label = mode === "system" ? "System" : mode === "dark" ? "Dark" : "Light"
  const icon = mode === "system" ? "🖥️" : mode === "dark" ? "🌙" : "☀️"

  return (
    <button
      type="button"
      onClick={cycleTheme}
      className="flex items-center gap-2 rounded-xl border px-3 py-2 text-sm font-medium smooth-card"
      style={{
        backgroundColor: "var(--bg-card)",
        borderColor: "var(--border)",
        color: "var(--text-secondary)",
      }}
      title={`Theme: ${label}`}
    >
      <span>{icon}</span>
      <span className="hidden sm:inline">{label}</span>
    </button>
  )
}

"use client"

import { useEffect, useState } from "react"

import { applyColorTheme, applyTheme, colorThemes, readStoredColorTheme, readStoredTheme, setStoredColorTheme, setStoredTheme, ColorThemeId, ThemeMode } from "@/lib/theme"

const modes: ThemeMode[] = ["system", "light", "dark"]

export default function ThemeToggle() {
  const [mode, setMode] = useState<ThemeMode>("system")
  const [colorTheme, setColorTheme] = useState<ColorThemeId>("mochaBrown")

  useEffect(() => {
    const stored = readStoredTheme()
    setMode(stored)
    const storedColor = readStoredColorTheme()
    setColorTheme(storedColor)
    applyTheme(stored)
    applyColorTheme(storedColor)

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
  const selectedColorTheme = colorThemes.find((theme) => theme.id === colorTheme) || colorThemes[0]

  const cycleColorTheme = () => {
    const index = colorThemes.findIndex((theme) => theme.id === colorTheme)
    const next = colorThemes[(index + 1) % colorThemes.length]
    setColorTheme(next.id)
    setStoredColorTheme(next.id)
    applyColorTheme(next.id)
  }

  return (
    <div className="flex items-center gap-2">
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
      <button
        type="button"
        onClick={cycleColorTheme}
        className="flex items-center gap-2 rounded-xl border px-3 py-2 text-sm font-medium smooth-card"
        style={{
          backgroundColor: "var(--bg-card)",
          borderColor: "var(--border)",
          color: "var(--text-secondary)",
        }}
        title={`Color: ${selectedColorTheme.name}`}
      >
        <span className="h-3 w-3 rounded-full" style={{ backgroundColor: "var(--primary)" }} />
        <span className="hidden sm:inline">{selectedColorTheme.name}</span>
      </button>
    </div>
  )
}

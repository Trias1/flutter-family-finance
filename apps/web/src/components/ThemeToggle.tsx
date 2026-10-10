"use client"

import { useEffect, useState } from "react"
import { Monitor, Moon, Palette, Sun } from "lucide-react"

import {
  applyColorTheme,
  applyTheme,
  colorThemes,
  readStoredColorTheme,
  readStoredTheme,
  setStoredColorTheme,
  setStoredTheme,
  ColorThemeId,
  ThemeMode,
} from "@/lib/theme"

const modes: ThemeMode[] = ["system", "light", "dark"]

function ThemeIcon({ mode }: { mode: ThemeMode }) {
  if (mode === "dark") return <Moon size={15} />
  if (mode === "light") return <Sun size={15} />
  return <Monitor size={15} />
}

export default function ThemeToggle() {
  const [mode, setMode] = useState<ThemeMode>("system")
  const [colorTheme, setColorTheme] = useState<ColorThemeId>("oceanBlue")
  const [mounted, setMounted] = useState(false)

  useEffect(() => {
    const stored = readStoredTheme()
    const storedColor = readStoredColorTheme()
    setMode(stored)
    setColorTheme(storedColor)
    applyTheme(stored)
    applyColorTheme(storedColor)
    setMounted(true)

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

  const cycleColorTheme = () => {
    const index = colorThemes.findIndex((theme) => theme.id === colorTheme)
    const next = colorThemes[(index + 1) % colorThemes.length]
    setColorTheme(next.id)
    setStoredColorTheme(next.id)
    applyColorTheme(next.id)
  }

  const label = mode === "system" ? "System" : mode === "dark" ? "Dark" : "Light"
  const selectedColorTheme = colorThemes.find((theme) => theme.id === colorTheme) || colorThemes[0]

  return (
    <div className="flex items-center gap-2">
      <button
        type="button"
        onClick={cycleTheme}
        className="flex items-center gap-2 rounded-xl border px-3 py-2 text-sm font-semibold transition-transform hover:-translate-y-0.5 glass-card"
        style={{ color: "var(--text-secondary)" }}
        title={`Theme: ${label}`}
        aria-label={`Theme: ${label}`}
      >
        <ThemeIcon mode={mounted ? mode : "system"} />
        <span className="hidden sm:inline">{label}</span>
      </button>
      <button
        type="button"
        onClick={cycleColorTheme}
        className="flex items-center gap-2 rounded-xl border px-3 py-2 text-sm font-semibold transition-transform hover:-translate-y-0.5 glass-card"
        style={{ color: "var(--text-secondary)" }}
        title={`Color: ${selectedColorTheme.name}`}
        aria-label={`Color: ${selectedColorTheme.name}`}
      >
        <Palette size={15} />
        <span className="h-3 w-3 rounded-full" style={{ backgroundColor: "var(--primary)" }} />
      </button>
    </div>
  )
}

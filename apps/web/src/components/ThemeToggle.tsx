"use client"

import { useEffect, useSyncExternalStore } from "react"
import { Monitor, Moon, Palette, Sun } from "lucide-react"

import {
  applyColorTheme,
  applyTheme,
  colorThemes,
  readStoredColorTheme,
  readStoredTheme,
  setStoredColorTheme,
  setStoredTheme,
  ThemeMode,
} from "@/lib/theme"

const modes: ThemeMode[] = ["system", "light", "dark"]
const CHANGE_EVENT = "family-finance-theme-change"

function subscribe(onChange: () => void) {
  window.addEventListener(CHANGE_EVENT, onChange)
  window.addEventListener("storage", onChange)
  return () => {
    window.removeEventListener(CHANGE_EVENT, onChange)
    window.removeEventListener("storage", onChange)
  }
}

function ThemeIcon({ mode }: { mode: ThemeMode }) {
  if (mode === "dark") return <Moon size={15} />
  if (mode === "light") return <Sun size={15} />
  return <Monitor size={15} />
}

export default function ThemeToggle() {
  // Server render and hydration use the defaults; the stored values take over right after.
  const mode = useSyncExternalStore(subscribe, readStoredTheme, () => "system" as ThemeMode)
  const colorTheme = useSyncExternalStore(subscribe, readStoredColorTheme, () => "oceanBlue" as const)

  useEffect(() => {
    applyTheme(readStoredTheme())
    applyColorTheme(readStoredColorTheme())

    const media = window.matchMedia("(prefers-color-scheme: dark)")
    const handleChange = () => {
      if (readStoredTheme() === "system") applyTheme("system")
    }
    media.addEventListener("change", handleChange)
    return () => media.removeEventListener("change", handleChange)
  }, [])

  const cycleTheme = () => {
    const next = modes[(modes.indexOf(mode) + 1) % modes.length]
    setStoredTheme(next)
    applyTheme(next)
    window.dispatchEvent(new Event(CHANGE_EVENT))
  }

  const cycleColorTheme = () => {
    const index = colorThemes.findIndex((theme) => theme.id === colorTheme)
    const next = colorThemes[(index + 1) % colorThemes.length]
    setStoredColorTheme(next.id)
    applyColorTheme(next.id)
    window.dispatchEvent(new Event(CHANGE_EVENT))
  }

  const label = mode === "system" ? "System" : mode === "dark" ? "Dark" : "Light"
  const selectedColorTheme = colorThemes.find((theme) => theme.id === colorTheme) || colorThemes[0]
  const buttonClass = "flex h-8 items-center gap-2 rounded-md border px-2.5 text-xs font-medium"
  const buttonStyle = { color: "var(--text-secondary)", borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }

  return (
    <div className="flex items-center gap-2">
      <button type="button" onClick={cycleTheme} className={buttonClass} style={buttonStyle} title={`Theme: ${label}`} aria-label={`Theme: ${label}`}>
        <ThemeIcon mode={mode} />
        <span className="hidden sm:inline">{label}</span>
      </button>
      <button type="button" onClick={cycleColorTheme} className={buttonClass} style={buttonStyle} title={`Color: ${selectedColorTheme.name}`} aria-label={`Color: ${selectedColorTheme.name}`}>
        <Palette size={15} />
        <span className="h-2.5 w-2.5 rounded-full" style={{ backgroundColor: "var(--primary)" }} />
      </button>
    </div>
  )
}

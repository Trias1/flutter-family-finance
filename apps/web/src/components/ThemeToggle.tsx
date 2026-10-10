"use client"

import { useEffect, useRef, useState, useSyncExternalStore } from "react"
import { Check, Monitor, Moon, Palette, Sun } from "lucide-react"
import { useTranslations } from "next-intl"

import {
  applyColorTheme,
  applyTheme,
  colorThemes,
  readStoredColorTheme,
  readStoredTheme,
  setStoredColorTheme,
  setStoredTheme,
  type ColorThemeId,
  type ThemeMode,
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
  const t = useTranslations("theme")
  // Server render and hydration use the defaults; the stored values take over right after.
  const mode = useSyncExternalStore(subscribe, readStoredTheme, () => "system" as ThemeMode)
  const colorTheme = useSyncExternalStore(subscribe, readStoredColorTheme, () => "oceanBlue" as const)
  const [paletteOpen, setPaletteOpen] = useState(false)
  const paletteRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!paletteOpen) return
    const close = (e: MouseEvent) => {
      if (paletteRef.current && !paletteRef.current.contains(e.target as Node)) setPaletteOpen(false)
    }
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setPaletteOpen(false)
    document.addEventListener("mousedown", close)
    document.addEventListener("keydown", onKey)
    return () => {
      document.removeEventListener("mousedown", close)
      document.removeEventListener("keydown", onKey)
    }
  }, [paletteOpen])

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

  const chooseColorTheme = (id: ColorThemeId) => {
    setStoredColorTheme(id)
    applyColorTheme(id)
    window.dispatchEvent(new Event(CHANGE_EVENT))
    setPaletteOpen(false)
  }

  const label = t(mode)
  const selectedColorTheme = colorThemes.find((theme) => theme.id === colorTheme) || colorThemes[0]
  const buttonClass = "flex h-8 items-center gap-2 rounded-md border px-2.5 text-xs font-medium"
  const buttonStyle = { color: "var(--text-secondary)", borderColor: "var(--border)", backgroundColor: "var(--bg-card)" }

  return (
    <div className="flex items-center gap-2">
      <button type="button" onClick={cycleTheme} className={buttonClass} style={buttonStyle} title={`${t("mode")}: ${label}`} aria-label={`${t("mode")}: ${label}`}>
        <ThemeIcon mode={mode} />
        <span className="hidden sm:inline">{label}</span>
      </button>
      <div className="relative" ref={paletteRef}>
        <button
          type="button"
          onClick={() => setPaletteOpen((v) => !v)}
          className={buttonClass}
          style={buttonStyle}
          title={`${t("color")}: ${selectedColorTheme.name}`}
          aria-label={`${t("color")}: ${selectedColorTheme.name}`}
          aria-haspopup="listbox"
          aria-expanded={paletteOpen}
        >
          <Palette size={15} />
          <span className="h-2.5 w-2.5 rounded-full" style={{ backgroundColor: "var(--primary)" }} />
        </button>
        {paletteOpen && (
          <ul role="listbox" aria-label={t("color")} className="absolute right-0 z-50 mt-1 w-48 overflow-hidden rounded-lg border py-1 text-sm" style={{ backgroundColor: "var(--bg-card)", borderColor: "var(--border)" }}>
            {colorThemes.map((theme) => {
              const selected = theme.id === colorTheme
              return (
                <li key={theme.id}>
                  <button
                    type="button"
                    role="option"
                    aria-selected={selected}
                    onClick={() => chooseColorTheme(theme.id)}
                    className="menu-item w-full"
                    style={{ color: selected ? "var(--text-primary)" : undefined, fontWeight: selected ? 600 : 400 }}
                  >
                    <span className="h-3.5 w-3.5 shrink-0 rounded-full border" style={{ backgroundColor: theme.swatch, borderColor: "var(--border)" }} />
                    <span className="flex-1">{theme.name}</span>
                    {selected && <Check size={14} />}
                  </button>
                </li>
              )
            })}
          </ul>
        )}
      </div>
    </div>
  )
}

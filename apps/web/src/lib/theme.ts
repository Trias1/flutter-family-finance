export type ThemeMode = "light" | "dark" | "system"
export type ColorThemeId = "oceanBlue" | "sage" | "lavender" | "charcoalGold" | "mochaBrown" | "softPink" | "roseGold"

export const THEME_STORAGE_KEY = "family-finance-theme"
export const COLOR_THEME_STORAGE_KEY = "family-finance-color-theme"

// `swatch` is the light-mode primary, matching the Android presets.
export const colorThemes: { id: ColorThemeId; name: string; swatch: string }[] = [
  { id: "oceanBlue", name: "Ocean Blue", swatch: "#1D4ED8" },
  { id: "sage", name: "Sage", swatch: "#3F6212" },
  { id: "lavender", name: "Lavender", swatch: "#7C3AED" },
  { id: "charcoalGold", name: "Charcoal Gold", swatch: "#111827" },
  { id: "mochaBrown", name: "Mocha Brown", swatch: "#6B3F2A" },
  { id: "softPink", name: "Soft Pink", swatch: "#BE185D" },
  { id: "roseGold", name: "Rose Gold", swatch: "#9F1239" },
]

export function getPreferredTheme(mode: ThemeMode) {
  if (mode !== "system") return mode
  if (typeof window === "undefined") return "light"
  return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"
}

export function applyTheme(mode: ThemeMode) {
  if (typeof document === "undefined") return
  const resolved = getPreferredTheme(mode)
  document.documentElement.dataset.theme = resolved
  document.documentElement.style.colorScheme = resolved
}

export function applyColorTheme(id: ColorThemeId) {
  if (typeof document === "undefined") return
  document.documentElement.dataset.colorTheme = id
}

export function readStoredTheme(): ThemeMode {
  if (typeof window === "undefined") return "system"
  const stored = window.localStorage.getItem(THEME_STORAGE_KEY)
  return stored === "light" || stored === "dark" || stored === "system" ? stored : "system"
}

export function setStoredTheme(mode: ThemeMode) {
  if (typeof window === "undefined") return
  window.localStorage.setItem(THEME_STORAGE_KEY, mode)
}

export function readStoredColorTheme(): ColorThemeId {
  if (typeof window === "undefined") return "oceanBlue"
  const stored = window.localStorage.getItem(COLOR_THEME_STORAGE_KEY)
  return colorThemes.some((theme) => theme.id === stored) ? (stored as ColorThemeId) : "oceanBlue"
}

export function setStoredColorTheme(id: ColorThemeId) {
  if (typeof window === "undefined") return
  window.localStorage.setItem(COLOR_THEME_STORAGE_KEY, id)
}


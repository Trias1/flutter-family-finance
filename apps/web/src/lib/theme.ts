export type ThemeMode = "light" | "dark" | "system"
export type ColorThemeId = "oceanBlue" | "sage" | "lavender" | "charcoalGold" | "mochaBrown" | "softPink" | "roseGold"

export const THEME_STORAGE_KEY = "family-finance-theme"
export const COLOR_THEME_STORAGE_KEY = "family-finance-color-theme"

// `swatch` is the light-mode primary, matching the Android presets.
export const colorThemes: { id: ColorThemeId; name: string; swatch: string }[] = [
  { id: "oceanBlue", name: "Ocean Blue", swatch: "#2B4C6F" },
  { id: "sage", name: "Sage", swatch: "#55704E" },
  { id: "lavender", name: "Lavender", swatch: "#5E5288" },
  { id: "charcoalGold", name: "Charcoal Gold", swatch: "#2A2D33" },
  { id: "mochaBrown", name: "Mocha Brown", swatch: "#6B4430" },
  { id: "softPink", name: "Soft Pink", swatch: "#9C4F63" },
  { id: "roseGold", name: "Rose Gold", swatch: "#8A4B45" },
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


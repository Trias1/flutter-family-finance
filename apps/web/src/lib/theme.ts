export type ThemeMode = "light" | "dark" | "system"

export const THEME_STORAGE_KEY = "family-finance-theme"

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

export function readStoredTheme(): ThemeMode {
  if (typeof window === "undefined") return "system"
  const stored = window.localStorage.getItem(THEME_STORAGE_KEY)
  return stored === "light" || stored === "dark" || stored === "system" ? stored : "system"
}

export function setStoredTheme(mode: ThemeMode) {
  if (typeof window === "undefined") return
  window.localStorage.setItem(THEME_STORAGE_KEY, mode)
}

import { doc, setDoc, serverTimestamp } from "firebase/firestore"

import { db } from "@/lib/firebase"
import { APP_VERSION_CODE, APP_VERSION_NAME } from "@/lib/app-info"

const PRESENCE_STORAGE_KEY = "family-finance-web-device-id"

function getBrowserLabel() {
  const ua = navigator.userAgent
  if (ua.includes("Edg")) return "Edge"
  if (ua.includes("Chrome")) return "Chrome"
  if (ua.includes("Firefox")) return "Firefox"
  if (ua.includes("Safari") && !ua.includes("Chrome")) return "Safari"
  return "Browser"
}

function getWebDeviceId() {
  const existing = window.localStorage.getItem(PRESENCE_STORAGE_KEY)
  if (existing) return existing
  const created = `web-${crypto.randomUUID()}`
  window.localStorage.setItem(PRESENCE_STORAGE_KEY, created)
  return created
}

export async function writeWebPresence(uid: string) {
  const deviceId = getWebDeviceId()
  // Overwrite rather than merge so older docs lose the email field they used to carry.
  await setDoc(
    doc(db, "users", uid, "devices", deviceId),
    {
      deviceId,
      platform: "web",
      brand: getBrowserLabel(),
      model: navigator.platform || "Unknown",
      androidVersion: "Web",
      appVersionName: APP_VERSION_NAME,
      appVersionCode: APP_VERSION_CODE,
      lastSeenAt: serverTimestamp(),
      privacyNote: "Web session metadata only. No contacts, location, files, photos, or sensitive device identifiers are collected.",
    },
  )
}

export function startWebPresence(uid: string) {
  let cancelled = false

  const sync = async () => {
    if (cancelled) return
    try {
      await writeWebPresence(uid)
    } catch {
      // Presence updates should never block app usage.
    }
  }

  void sync()
  const interval = window.setInterval(sync, 60_000)
  const visibilityHandler = () => {
    if (document.visibilityState === "visible") void sync()
  }

  document.addEventListener("visibilitychange", visibilityHandler)

  return () => {
    cancelled = true
    window.clearInterval(interval)
    document.removeEventListener("visibilitychange", visibilityHandler)
  }
}

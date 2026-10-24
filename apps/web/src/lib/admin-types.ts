// Shapes returned by /api/admin/overview, shared by the admin page and the
// development-only demo data.

export type AdminDevice = {
  id: string
  platform: string
  brand: string
  model: string
  osVersion: string
  appVersionName: string
  appVersionCode: number | null
  lastSeenAt: number | null
}

export type AdminUser = {
  id: string
  name: string
  role: "superadmin" | "admin" | "member"
  disabled: boolean
  devices: AdminDevice[]
  hasWeb: boolean
  latestSource: string
  appVersionLabel: string
  online: boolean
  outdated: boolean
  lastSeenAt: number | null
}

export type AdminAnnouncement = {
  active: boolean
  messageId: string
  messageEn: string
  tone: "info" | "maintenance"
}

export type AdminOverview = {
  stats: {
    totalUsers: number
    totalFamilies: number
    onlineUsers: number
    activeToday: number
    outdatedUsers: number
    activeDevices: number
    latestVersionName: string
    latestVersionCode: number
    webVersionName: string
    webVersionCode: number
  }
  growth: { day: string; users: number; active: number }[]
  release: { forceUpdate: boolean; releaseNotes: string }
  announcement: AdminAnnouncement
  versions: { name: string; value: number }[]
  users: AdminUser[]
  page: number
  pageSize: number
  total: number
}

export type AdminFilter = "all" | "online" | "android" | "web" | "outdated" | "disabled"
export type OverviewQuery = { page: number; q: string; filter: AdminFilter }

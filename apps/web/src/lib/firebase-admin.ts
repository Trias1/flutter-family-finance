import "server-only"

import {
  initializeApp as initializeAdminApp,
  getApps as getAdminApps,
  cert,
} from "firebase-admin/app"
import { getAuth as getAdminAuth } from "firebase-admin/auth"
import { getFirestore as getAdminFirestore } from "firebase-admin/firestore"

const serviceAccountBase64 = process.env.FIREBASE_SERVICE_ACCOUNT_B64

function getServiceAccount() {
  if (!serviceAccountBase64) {
    return null
  }
  try {
    return JSON.parse(
      Buffer.from(serviceAccountBase64, "base64").toString("utf-8")
    )
  } catch (error) {
    console.error("Invalid FIREBASE_SERVICE_ACCOUNT_B64", error)
    return null
  }
}

const sa = getServiceAccount()

let adminAuth: ReturnType<typeof getAdminAuth> | null = null
let adminDb: ReturnType<typeof getAdminFirestore> | null = null
let adminApp: ReturnType<typeof initializeAdminApp> | null = null

if (sa) {
  try {
    adminApp =
      getAdminApps().length === 0
        ? initializeAdminApp({ credential: cert(sa), storageBucket: `${sa.project_id}.firebasestorage.app` })
        : getAdminApps()[0]
    adminAuth = getAdminAuth(adminApp)
    adminDb = getAdminFirestore(adminApp)
  } catch (error) {
    console.error("Failed to initialize Firebase Admin", error)
  }
}

export { adminApp, adminAuth, adminDb }

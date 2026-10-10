import { initializeApp, getApps } from "firebase/app"
import { getAuth } from "firebase/auth"
import {
  getFirestore,
  initializeFirestore,
  memoryLocalCache,
  persistentLocalCache,
  persistentMultipleTabManager,
  type Firestore,
} from "firebase/firestore"

const firebaseConfig = {
  apiKey: "AIzaSyA9Nxu_CrS3Rlg_V0miRImVUPeFtMbEHck",
  authDomain: "tabunganapps.firebaseapp.com",
  projectId: "tabunganapps",
  storageBucket: "tabunganapps.firebasestorage.app",
  messagingSenderId: "352640025586",
  appId: "1:352640025586:web:76a543ecc8cb04177be16b",
  measurementId: "G-5ZWCFRTTV7",
}

const isFirstInit = getApps().length === 0
const app = isFirstInit ? initializeApp(firebaseConfig) : getApps()[0]
const auth = getAuth(app)

// In the browser, keep a persistent cache shared across tabs so the dashboard
// shows the last known data instantly and keeps working offline.
function createDb(): Firestore {
  if (!isFirstInit) return getFirestore(app)
  const localCache =
    typeof window === "undefined"
      ? memoryLocalCache()
      : persistentLocalCache({ tabManager: persistentMultipleTabManager() })
  try {
    return initializeFirestore(app, { localCache })
  } catch {
    return getFirestore(app)
  }
}

const db = createDb()

export { app, auth, db }

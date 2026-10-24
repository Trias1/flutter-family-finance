import { initializeApp, getApps } from "firebase/app"
import { getAuth, signOut } from "firebase/auth"
import {
  clearIndexedDbPersistence,
  getFirestore,
  initializeFirestore,
  memoryLocalCache,
  persistentLocalCache,
  persistentMultipleTabManager,
  terminate,
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

/**
 * Signs out and wipes the on-device Firestore cache, so finance data is not
 * left behind on a shared computer. The Firestore instance is unusable
 * afterwards, so callers must do a full page load (not a client navigation).
 */
async function signOutAndClear() {
  await signOut(auth)
  try {
    await terminate(db)
    await clearIndexedDbPersistence(db)
  } catch {
    // Another tab may still hold the cache open; it is cleared on its next sign-out.
  }
}

export { app, auth, db, signOutAndClear }

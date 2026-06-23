import { initializeApp, getApps } from "firebase/app"
import { getAuth } from "firebase/auth"
import { getFirestore } from "firebase/firestore"

const firebaseConfig = {
  apiKey: "AIzaSyA9Nxu_CrS3Rlg_V0miRImVUPeFtMbEHck",
  authDomain: "tabunganapps.firebaseapp.com",
  projectId: "tabunganapps",
  storageBucket: "tabunganapps.firebasestorage.app",
  messagingSenderId: "352640025586",
  appId: "1:352640025586:web:76a543ecc8cb04177be16b",
  measurementId: "G-5ZWCFRTTV7",
}

const app = getApps().length === 0 ? initializeApp(firebaseConfig) : getApps()[0]
const auth = getAuth(app)
const db = getFirestore(app)

export { app, auth, db }

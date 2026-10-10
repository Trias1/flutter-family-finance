import type { User } from "firebase/auth"

// Email/password accounts must verify their address before reading any
// finance or family data; firestore.rules enforce the same thing. Google
// accounts arrive verified.
export function needsEmailVerification(user: User) {
  return !user.emailVerified && user.providerData.some((p) => p.providerId === "password")
}

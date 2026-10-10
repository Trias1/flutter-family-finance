// Security rules tests. Run against the Firestore emulator:
//   firebase emulators:exec --only firestore "npm --prefix firestore-tests test"

import { readFileSync } from "node:fs"
import { after, before, beforeEach, describe, test } from "node:test"

import { assertFails, assertSucceeds, initializeTestEnvironment } from "@firebase/rules-unit-testing"
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  limit,
  query,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  where,
  writeBatch,
} from "firebase/firestore"

let env

const now = Timestamp.now()

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-family-finance",
    firestore: { rules: readFileSync(new URL("../firestore.rules", import.meta.url), "utf8") },
  })
})

after(async () => {
  await env?.cleanup()
})

// Fixture: family F1 owned by alice with member bob; carol and dave have no family.
beforeEach(async () => {
  await env.clearFirestore()
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore()
    const user = (id, extra = {}) => setDoc(doc(db, "users", id), { name: id, email: `${id}@x.test`, familyId: null, role: "member", createdAt: now, familyHistory: [], ...extra })
    await user("alice", { familyId: "F1", role: "admin" })
    await user("bob", { familyId: "F1" })
    await user("carol")
    await user("dave")
    await setDoc(doc(db, "families", "F1"), { name: "Keluarga A", inviteCode: "ABCD2345", createdBy: "alice", createdAt: now })
    await setDoc(doc(db, "family_invites", "ABCD2345"), { familyId: "F1", familyName: "Keluarga A", createdBy: "alice" })
    await setDoc(doc(db, "families", "LEGACY"), { name: "Lama", inviteCode: "OLD123", createdBy: "carol", createdAt: now })
    await setDoc(doc(db, "expenses", "e-bob"), { familyId: "F1", userId: "bob", amount: 1000, category: "Makan", date: now, createdAt: now })
    await setDoc(doc(db, "expenses", "e-carol"), { familyId: "carol", userId: "carol", amount: 500, category: "Makan", date: now, createdAt: now })
  })
})

const as = (uid) => env.authenticatedContext(uid).firestore()

describe("joining a family", () => {
  test("cannot set familyId to another family without a code", async () => {
    await assertFails(updateDoc(doc(as("carol"), "users", "carol"), { familyId: "F1" }))
  })

  test("cannot set familyId to another user's uid (personal scope)", async () => {
    await assertFails(updateDoc(doc(as("dave"), "users", "dave"), { familyId: "carol" }))
  })

  test("can join with the right invite code", async () => {
    await assertSucceeds(updateDoc(doc(as("carol"), "users", "carol"), { familyId: "F1", joinCode: "ABCD2345" }))
  })

  test("a code for another family does not work", async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), "family_invites", "ZZZZ9999"), { familyId: "OTHER", familyName: "x", createdBy: "x" }))
    await assertFails(updateDoc(doc(as("carol"), "users", "carol"), { familyId: "F1", joinCode: "ZZZZ9999" }))
  })

  test("cannot make yourself admin of someone else's family", async () => {
    await assertFails(updateDoc(doc(as("carol"), "users", "carol"), { familyId: "F1", joinCode: "ABCD2345", role: "admin" }))
  })

  test("cannot grant yourself systemRole", async () => {
    await assertFails(updateDoc(doc(as("carol"), "users", "carol"), { systemRole: "superadmin" }))
  })

  test("can leave a family", async () => {
    await assertSucceeds(updateDoc(doc(as("bob"), "users", "bob"), { familyId: null, role: "member" }))
  })

  test("invite codes can be read one at a time but not listed", async () => {
    await assertSucceeds(getDoc(doc(as("carol"), "family_invites", "ABCD2345")))
    await assertFails(getDocs(collection(as("carol"), "family_invites")))
  })

  test("families cannot be listed, even with limit 1", async () => {
    await assertFails(getDocs(query(collection(as("carol"), "families"), limit(1))))
    await assertFails(getDocs(query(collection(as("carol"), "families"), where("inviteCode", "==", "ABCD2345"), limit(1))))
  })
})

describe("creating a family", () => {
  test("family + invite in one batch, then owner joins as admin", async () => {
    const db = as("dave")
    const batch = writeBatch(db)
    batch.set(doc(db, "families", "F2"), { name: "Keluarga D", inviteCode: "DAVE2345", createdBy: "dave", createdAt: now, photoUrl: null })
    batch.set(doc(db, "family_invites", "DAVE2345"), { familyId: "F2", familyName: "Keluarga D", createdBy: "dave" })
    await assertSucceeds(batch.commit())
    await assertSucceeds(updateDoc(doc(db, "users", "dave"), { familyId: "F2", role: "admin" }))
  })

  test("cannot create a family on behalf of someone else", async () => {
    await assertFails(setDoc(doc(as("dave"), "families", "F3"), { name: "x", inviteCode: "XXXX2345", createdBy: "alice", createdAt: now }))
  })

  test("cannot create a family whose id is a user's uid", async () => {
    await assertFails(setDoc(doc(as("dave"), "families", "carol"), { name: "x", inviteCode: "XXXX2345", createdBy: "dave", createdAt: now }))
  })

  test("cannot create an invite pointing at someone else's family", async () => {
    await assertFails(setDoc(doc(as("dave"), "family_invites", "ABCD2345X"), { familyId: "F1", familyName: "x", createdBy: "dave" }))
  })

  test("owner of a legacy family can create its missing invite", async () => {
    await assertSucceeds(setDoc(doc(as("carol"), "family_invites", "OLD123"), { familyId: "LEGACY", familyName: "Lama", createdBy: "carol" }))
  })
})

describe("owner actions", () => {
  test("owner can remove a member", async () => {
    await assertSucceeds(updateDoc(doc(as("alice"), "users", "bob"), { familyId: null, role: "member" }))
  })

  test("owner cannot edit other fields on a member", async () => {
    await assertFails(updateDoc(doc(as("alice"), "users", "bob"), { name: "renamed" }))
  })

  test("owner cannot move a member into another family", async () => {
    await assertFails(updateDoc(doc(as("alice"), "users", "bob"), { familyId: "LEGACY" }))
  })

  test("a member cannot remove another member", async () => {
    await env.withSecurityRulesDisabled((ctx) => updateDoc(doc(ctx.firestore(), "users", "carol"), { familyId: "F1" }))
    await assertFails(updateDoc(doc(as("bob"), "users", "carol"), { familyId: null }))
  })

  test("ownership transfer to a member", async () => {
    const db = as("alice")
    const batch = writeBatch(db)
    batch.update(doc(db, "users", "alice"), { role: "member" })
    batch.update(doc(db, "users", "bob"), { role: "admin" })
    batch.update(doc(db, "families", "F1"), { createdBy: "bob" })
    batch.set(doc(db, "family_invites", "ABCD2345"), { createdBy: "bob" }, { merge: true })
    await assertSucceeds(batch.commit())
  })

  test("ownership cannot go to a non-member", async () => {
    await assertFails(updateDoc(doc(as("alice"), "families", "F1"), { createdBy: "carol" }))
  })
})

describe("profiles", () => {
  test("family members can read each other", async () => {
    await assertSucceeds(getDoc(doc(as("bob"), "users", "alice")))
  })

  test("users without a family cannot read each other", async () => {
    await assertFails(getDoc(doc(as("dave"), "users", "carol")))
  })

  test("outsiders cannot read a family member's profile", async () => {
    await assertFails(getDoc(doc(as("carol"), "users", "alice")))
  })

  test("new user doc cannot start inside a family or as admin", async () => {
    const db = as("eve")
    await assertFails(setDoc(doc(db, "users", "eve"), { name: "eve", email: "e@x.test", familyId: "F1", role: "member", createdAt: now }))
    await assertFails(setDoc(doc(db, "users", "eve"), { name: "eve", email: "e@x.test", familyId: null, role: "admin", createdAt: now }))
    await assertSucceeds(setDoc(doc(db, "users", "eve"), { name: "eve", email: "e@x.test", familyId: null, role: "member", createdAt: serverTimestamp() }))
  })
})

describe("finance data", () => {
  test("members read their family's data; outsiders cannot", async () => {
    await assertSucceeds(getDocs(query(collection(as("alice"), "expenses"), where("familyId", "==", "F1"))))
    await assertFails(getDocs(query(collection(as("carol"), "expenses"), where("familyId", "==", "F1"))))
  })

  test("personal data is private to its owner", async () => {
    await assertSucceeds(getDoc(doc(as("carol"), "expenses", "e-carol")))
    await assertFails(getDoc(doc(as("dave"), "expenses", "e-carol")))
  })

  test("cannot write data into another family", async () => {
    await assertFails(setDoc(doc(as("carol"), "expenses", "x"), { familyId: "F1", userId: "carol", amount: 1, date: now, createdAt: now }))
  })

  test("cannot record an expense as someone else", async () => {
    await assertFails(setDoc(doc(as("bob"), "expenses", "x"), { familyId: "F1", userId: "alice", amount: 1, date: now, createdAt: now }))
  })

  test("amounts must be non-negative numbers", async () => {
    await assertFails(setDoc(doc(as("bob"), "expenses", "x"), { familyId: "F1", userId: "bob", amount: -5, date: now, createdAt: now }))
    await assertFails(setDoc(doc(as("bob"), "expenses", "y"), { familyId: "F1", userId: "bob", amount: "1000", date: now, createdAt: now }))
    await assertSucceeds(setDoc(doc(as("bob"), "expenses", "z"), { familyId: "F1", userId: "bob", amount: 1000, date: now, createdAt: now }))
  })

  test("a member cannot delete another member's expense; the owner can", async () => {
    await env.withSecurityRulesDisabled((ctx) => updateDoc(doc(ctx.firestore(), "users", "carol"), { familyId: "F1" }))
    await assertFails(deleteDoc(doc(as("carol"), "expenses", "e-bob")))
    await assertSucceeds(deleteDoc(doc(as("alice"), "expenses", "e-bob")))
  })

  test("the author can delete their own expense", async () => {
    await assertSucceeds(deleteDoc(doc(as("bob"), "expenses", "e-bob")))
  })
})

describe("server-only collections", () => {
  test("rate_limits and admin_audit are closed to clients", async () => {
    await assertFails(getDoc(doc(as("alice"), "rate_limits", "x")))
    await assertFails(setDoc(doc(as("alice"), "admin_audit", "x"), { a: 1 }))
  })
})

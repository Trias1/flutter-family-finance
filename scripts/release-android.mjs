#!/usr/bin/env node
// One command for an Android release, so the update notice can never point
// at an APK that is not online yet:
//   1. read the version from pubspec.yaml
//   2. build the release APK and check it is signed with the same key as the
//      APK currently published (otherwise phones refuse the update)
//   3. copy it to apps/web/public and write the version into the web app
//   4. deploy the web app to production (Vercel)
//   5. only after the deploy is live: update Firestore app_config/android,
//      which is what installed apps read to show "Update available"
//
// Usage (from the repo root):
//   node scripts/release-android.mjs [--notes "What changed"] [--skip-build] [--dry-run]
// --dry-run stops before deploying and touching Firestore.
//
// Needs: flutter, the Vercel CLI (logged in), the Firebase CLI (logged in),
// Android build-tools (apksigner) and Java. No secrets are stored here.

import { execFileSync, execSync } from "node:child_process"
import { copyFileSync, existsSync, readdirSync, readFileSync, statSync, writeFileSync } from "node:fs"
import { createRequire } from "node:module"
import { join, resolve } from "node:path"

const ROOT = resolve(import.meta.dirname, "..")
const PROJECT = "tabunganapps"
const VERCEL_SCOPE = "team_HGdecLy9KyOetb6vsPOpAWxj"
const APK_URL = "https://family-finance.tzm.web.id/FamilyFinance.apk"
const BUILT_APK = join(ROOT, "build", "app", "outputs", "flutter-apk", "app-release.apk")
const PUBLIC_APK = join(ROOT, "apps", "web", "public", "FamilyFinance.apk")
const APP_INFO = join(ROOT, "apps", "web", "src", "lib", "app-info.ts")
const ANDROID_SDK = process.env.ANDROID_SDK_ROOT || process.env.ANDROID_HOME || "D:\\AndroidSDK"

const args = process.argv.slice(2)
const flag = (name) => args.includes(name)
const option = (name) => {
  const i = args.indexOf(name)
  return i >= 0 ? args[i + 1] : undefined
}
const notes = option("--notes") ?? "Perbaikan dan fitur baru. / Fixes and new features."

function step(text) {
  console.log(`\n== ${text}`)
}

function fail(text) {
  console.error(`\nRelease stopped: ${text}`)
  process.exit(1)
}

function run(cmd, cmdArgs, opts = {}) {
  execFileSync(cmd, cmdArgs, { stdio: "inherit", cwd: ROOT, shell: process.platform === "win32", ...opts })
}

// 1. Version
step("Reading version from pubspec.yaml")
const match = readFileSync(join(ROOT, "pubspec.yaml"), "utf8").match(/^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$/m)
if (!match) fail("pubspec.yaml has no version like 1.2.3+45")
const versionName = match[1]
const versionCode = Number(match[2])
console.log(`Version ${versionName} (${versionCode})`)

const current = readFileSync(APP_INFO, "utf8").match(/APP_VERSION_CODE\s*=\s*(\d+)/)
if (current && Number(current[1]) >= versionCode && !flag("--skip-build")) {
  fail(`versionCode ${versionCode} is not higher than the published ${current[1]}; bump pubspec.yaml first`)
}

// 2. Build and signature check
if (!flag("--skip-build")) {
  step("Building the release APK")
  run("flutter", ["build", "apk", "--release"])
}
if (!existsSync(BUILT_APK)) fail(`no APK at ${BUILT_APK}`)

function apksigner() {
  const tools = join(ANDROID_SDK, "build-tools")
  const versions = readdirSync(tools).sort().reverse()
  for (const v of versions) {
    const bin = join(tools, v, process.platform === "win32" ? "apksigner.bat" : "apksigner")
    if (existsSync(bin)) return bin
  }
  fail("apksigner not found in Android build-tools")
}

function certDigest(apk) {
  const out = execFileSync(apksigner(), ["verify", "--print-certs", apk], { encoding: "utf8", shell: process.platform === "win32" })
  const line = out.split(/\r?\n/).find((l) => l.includes("certificate SHA-256 digest"))
  if (!line) fail(`could not read the signing certificate of ${apk}`)
  return line.split(":").pop().trim()
}

step("Checking the signing key")
const newDigest = certDigest(BUILT_APK)
if (existsSync(PUBLIC_APK)) {
  const oldDigest = certDigest(PUBLIC_APK)
  if (oldDigest !== newDigest) fail("the new APK is signed with a different key than the published one; phones would refuse the update")
  console.log("Same signing key as the published APK.")
} else {
  console.log("No published APK to compare with (first release).")
}

// 3. Publish into the web app
step("Copying the APK and writing the web's version info")
copyFileSync(BUILT_APK, PUBLIC_APK)
const size = statSync(PUBLIC_APK).size
writeFileSync(
  APP_INFO,
  readFileSync(APP_INFO, "utf8")
    .replace(/APP_VERSION_NAME\s*=\s*"[^"]*"/, `APP_VERSION_NAME = "${versionName}"`)
    .replace(/APP_VERSION_CODE\s*=\s*\d+/, `APP_VERSION_CODE = ${versionCode}`),
)
console.log(`APK ${(size / 1048576).toFixed(1)} MB, app-info.ts set to ${versionName} (${versionCode})`)

if (flag("--dry-run")) {
  console.log("\nDry run: stopping before deploy and Firestore. Nothing was published.")
  process.exit(0)
}

// 4. Deploy the web app (Root Directory apps/web; .vercelignore limits the upload)
step("Deploying the web app to production")
run("vercel", ["deploy", "--prod", "--yes", "--scope", VERCEL_SCOPE])

step("Waiting until the new APK is served")
let live = false
for (let i = 0; i < 12 && !live; i++) {
  const res = await fetch(`${APK_URL}?v=${versionCode}`, { method: "HEAD", cache: "no-store" })
  live = res.ok && Number(res.headers.get("content-length")) === size
  if (!live) await new Promise((r) => setTimeout(r, 10_000))
}
if (!live) fail("the deployed APK does not match the local one yet; Firestore was NOT updated. Re-run with --skip-build once it is live")

// 5. Tell installed apps about the update
step("Updating Firestore app_config/android")
const npmRoot = execSync("npm root -g", { encoding: "utf8" }).trim()
const firebaseAuth = createRequire(import.meta.url)(join(npmRoot, "firebase-tools", "lib", "auth"))
const account = firebaseAuth.getGlobalDefaultAccount()
if (!account) fail("the Firebase CLI is not logged in (run: firebase login)")
const { access_token: token } = await firebaseAuth.getAccessToken(account.tokens.refresh_token, [
  "https://www.googleapis.com/auth/cloud-platform",
])
const fields = {
  latestVersionName: { stringValue: versionName },
  latestVersionCode: { integerValue: String(versionCode) },
  apkUrl: { stringValue: APK_URL },
  releaseNotes: { stringValue: notes },
  updatedAt: { timestampValue: new Date().toISOString() },
}
const mask = Object.keys(fields).map((f) => `updateMask.fieldPaths=${f}`).join("&")
const url = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/app_config/android?${mask}`
const res = await fetch(url, {
  method: "PATCH",
  headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
  body: JSON.stringify({ fields }),
})
if (!res.ok) fail(`Firestore update failed: ${res.status} ${(await res.json()).error?.message ?? ""}`)
console.log(`Installed apps will now offer ${versionName} (${versionCode}).`)
console.log("\nDone. Commit apps/web/src/lib/app-info.ts (the APK itself is not in git).")

# Family Finance Manager

A family money app: every member records income and spending on Android, and the whole family follows the same numbers on a web dashboard. Built with Flutter, Firebase (Auth + Firestore) and a Next.js companion site.

- Production web: https://finance.west-solutions.web.id (also https://finance-family-prod.vercel.app)
- Firebase project: `tabunganapps`
- Current Android version: 1.1.13+17

## What it does

**Android app (`lib/`)**

- Income and spending with categories, notes and recurring transactions (generated automatically, never twice)
- Monthly budgets per category, with alerts and rollover (last month's remainder adds to the limit)
- A warning before saving what looks like a double entry (same category and amount within 3 hours), and a "possible double" mark in History
- Savings goals, including gold tracked in grams
- Debts and receivables with repayment history
- Bill reminders scheduled on the phone (the day before and on the due day)
- Reports, PDF export and a 30-day cash-flow estimate
- Family mode: one family shares records, budgets and reports
- Dashboard: this month's balance, spending by member (family mode), top categories vs last month, debts, a 30-day outlook
- Fingerprint app lock (like WhatsApp), Google Drive backup, home-screen widget, multi-currency (per family or personal, shared with the web), light/dark themes with seven color presets, Indonesian and English
- Account deletion in Settings

**Web (`apps/web/`)**

- Public site: home, guide (with a step index), sign-in, sign-up, password reset
- Dashboard (read-only, live): overview, transactions with filters and search, budgets and savings, debts, reports. Data recorded on Android appears within seconds; an offline cache makes reloads instant
- Admin panel (superadmin only): users, devices, app versions and maintenance actions. It shows usernames and devices only, never emails or finance data
- Indonesian and English throughout; the dashboard follows the user's theme and color preset, public pages always render light

## How families and access work

- Finance records carry a `familyId`. With a family it is the family's id; without one it is the user's own uid (personal records).
- A family has one owner and an 8-character invite code (`Random.secure`, unambiguous characters). Codes are looked up through `family_invites/{code}`, which can be read one code at a time but never listed.
- Joining requires the family's **current** code. The owner can rotate the code; members the owner removes are listed under `families/{id}/banned` and cannot rejoin.
- Authored records (income, spending, debts, recurring) can be edited or deleted only by their author or the family owner.
- `systemRole: superadmin` can only be set from the Firebase console. Clients can never write it.

All of this is enforced in `firestore.rules`, not just in the apps.

## Security notes

- Email/password accounts must verify their email before any finance or family data is readable; the rules enforce it (`isVerified()`).
- Firestore rules are covered by tests in `firestore-tests/` (44 cases: email verification, joining, bans, code rotation, cross-family reads, role escalation, record ownership, size limits).
- Web API routes (`apps/web/src/app/api/admin/*`) verify the Firebase ID token server-side (revocation included), check the superadmin role on every request, cap request bodies, rate-limit sensitive actions and never return internal errors.
- The web app sends a per-request nonce Content-Security-Policy (`src/proxy.ts`), HSTS, frame denial and related headers.
- Sign-in has progressive client-side back-off on failures, generic error messages, password reset and required email verification. Signing out clears the Firestore cache on the web and on the phone.
- Account deletion runs on the server (`/api/account/delete`): it needs a sign-in from the last 5 minutes, removes personal records, profile and devices, hands an owned family to another member (or deletes an empty one) and finally deletes the Auth user.
- No API keys ship in the Android app. The Firebase web config in the code is public by design; the service account lives only in Vercel environment variables.

Recommended Firebase console settings: Email Enumeration Protection, a password policy (8+ characters) and App Check.

## Project structure

```
lib/                     Flutter app
  core/                  theme, services, utilities, shared widgets
  data/                  models, repositories, Firestore/Auth data sources
  features/<name>/       pages and providers per feature
  routes/                GoRouter configuration
apps/web/                Next.js 16 site (App Router, next-intl, Tailwind 4)
  src/app/[locale]/      public pages, dashboard, admin
  src/app/api/admin/     superadmin API routes
  src/lib/               Firebase clients, live family data, API auth helpers
  messages/              id.json and en.json
firestore.rules          security rules (deployed to tabunganapps)
firestore-tests/         rules tests for the Firestore emulator
```

## Running locally

**Android**

```bash
flutter pub get
flutter run
```

Release builds read signing settings from `android/key.properties` (not committed). Without it, release builds fall back to debug signing.

**Web**

```bash
cd apps/web
npm install
npm run dev
```

The dashboard works against production Firebase with the user's own account. Admin API routes need `FIREBASE_SERVICE_ACCOUNT_B64` (base64 of a service-account JSON) in the environment; without it they answer 503. In development, `?demo=1` on `/dashboard` or `/admin` shows sample data without touching Firestore; production builds drop this.

**Rules tests** (needs Java 17+)

```bash
npm --prefix firestore-tests install
firebase emulators:exec --only firestore --project demo-family-finance "npm --prefix firestore-tests test"
```

## Checks before release

```bash
flutter analyze
flutter test
cd apps/web && npx tsc --noEmit -p . && npm run lint && npm run build && npm audit --omit=dev
```

## Deploying

- **Web:** the Vercel project `financefamily` has Root Directory `apps/web`. From the repo root: `vercel deploy --prod` (`.vercelignore` uploads only `apps/web`). Pushes to GitHub also build previews.
- **Firestore rules:** `firebase deploy --only firestore:rules --project tabunganapps`. Run the rules tests first.
- **Android:** bump `version` in `pubspec.yaml`, then run `node scripts/release-android.mjs --notes "what changed"` from the repo root. It builds and signature-checks the APK, publishes it with the web app and, only once it is live, updates `app_config/android` so installed apps offer the update. Add `--dry-run` to stop before publishing.

When a rules change affects how the app writes data, release the new APK and the rules together.

## License

Internal use.

# Family Finance Manager

A family money app: every member records income and spending on Android, and the whole family follows the same numbers on a web dashboard. Built with Flutter, Firebase (Auth + Firestore) and a Next.js companion site.

- Production web: https://finance-family-prod.vercel.app (also https://family-finance.tzm.web.id)
- Firebase project: `tabunganapps`
- Current Android version: 1.1.10+14

## What it does

**Android app (`lib/`)**

- Income and spending with categories, notes and recurring transactions
- Monthly budgets per category, with alerts and rollover
- Savings goals, including gold tracked in grams
- Debts and receivables with repayment history
- Bill reminders with notifications
- Reports, PDF export and a 30-day cash-flow estimate
- Family mode: one family shares records, budgets and reports
- Fingerprint unlock, Google Drive backup, home-screen widget, multi-currency, light/dark themes with seven color presets, Indonesian and English

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

- Firestore rules are covered by tests in `firestore-tests/` (39 cases: joining, bans, code rotation, cross-family reads, role escalation, record ownership, size limits).
- Web API routes (`apps/web/src/app/api/admin/*`) verify the Firebase ID token server-side (revocation included), check the superadmin role on every request, cap request bodies, rate-limit sensitive actions and never return internal errors.
- The web app sends a per-request nonce Content-Security-Policy (`src/proxy.ts`), HSTS, frame denial and related headers.
- Sign-in has progressive client-side back-off on failures, generic error messages, password reset and email verification. Signing out clears the browser's Firestore cache.
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

- **Web:** from `apps/web`, `vercel deploy --prod` (the Vercel project builds from that folder).
- **Firestore rules:** `firebase deploy --only firestore:rules --project tabunganapps`. Run the rules tests first.
- **Android:** bump `version` in `pubspec.yaml`, build with `flutter build apk --release`, publish the APK, then use "Sync Android config" in the admin panel so older apps are told to update.

When a rules change affects how the app writes data, release the new APK and the rules together.

## License

Internal use.

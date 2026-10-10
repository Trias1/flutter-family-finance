# Family Finance Manager 💰

A comprehensive family finance management mobile app built with **Flutter** + **Firebase**, with a companion **Next.js** admin web app.

## ✨ Features

- **Dashboard** — Overview of income, expenses, balance, and charts
- **Income & Expense Tracking** — Categorized transactions with date filtering
- **Budget Management** — Monthly budgets with rollover, alerts, and history
- **Savings Goals** — Track savings targets with auto-deduction, gold investment support
- **Debt Management** — Track debts/payables with payment history
- **Recurring Transactions** — Auto-generate periodic income/expenses
- **Bill Reminders** — Due date tracking with notifications
- **Reports** — Charts, PDF export, cash flow prediction (30-day)
- **Family Mode** — Share finances with family members, role-based access
- **Multi Currency** — Support for IDR, USD, EUR, and more
- **AI Advisor** — Financial insights and recommendations
- **Backup & Restore** — Google Drive backup
- **Android Home Widget** — Quick balance view on home screen
- **Biometric Auth** — Fingerprint / face unlock
- **Receipt Scanner** — Scan and auto-categorize receipts
- **Dark Mode** — With 7 theme presets (Mocha Brown, Ocean Blue, Lavender, etc.)
- **EN/ID Localization** — Full English & Indonesian language support

## 🛠 Tech Stack

| Layer | Technology |
|-------|-----------|
| **Frontend** | Flutter 3.x, Dart 3.x |
| **State Management** | Riverpod + Riverpod Annotation |
| **Routing** | GoRouter 14.x |
| **Backend** | Firebase (Auth, Firestore, Storage, FCM, Crashlytics) |
| **Charts** | fl_chart, table_calendar |
| **PDF** | pdf + printing |
| **Web Admin** | Next.js, Tailwind CSS, next-intl |
| **Hosting** | Vercel (web), Firebase (backend) |

## 📱 Platform Support

- ✅ **Android** (primary, with APK distribution)
- ⏳ **iOS** (configured, not actively deployed)
- ⏳ **Web (Flutter)** (configured, minimal use)
- ✅ **Web (Next.js)** Admin dashboard

## 🚀 Getting Started

```bash
# Clone & install dependencies
flutter pub get

# Run on device/emulator
flutter run

# Build APK release
flutter build apk --release
```

## 📦 Project Structure

```
lib/
├── core/           # Shared utilities, theme, locale, services
├── data/           # Models, repositories, datasources
├── domain/         # Entities
├── features/       # Feature modules (auth, budget, transactions, etc.)
└── routes/         # GoRouter configuration

apps/web/           # Next.js admin dashboard
```

## 🔐 Environment

- Firebase project: `tabunganapps`
- Production URL: `https://finance-family-prod.vercel.app`
- APK download: Available on the landing page

## 📄 License

Internal use — Family Finance Manager

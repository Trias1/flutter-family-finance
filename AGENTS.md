# AGENTS - Family Finance Manager

## Project Rules
- Flutter 3.x with Riverpod, GoRouter, Firebase
- Keep existing page structure untouched unless modifying for new features
- Use `CurrencyFormatter` for all currency display (will be updated for multi-currency)
- Use `NotificationService` singleton for all local notifications
- All new features go in `lib/features/<name>/`
- Models in `lib/data/models/`, repositories in `lib/data/repositories/`
- Pages in `lib/features/<name>/presentation/pages/`
- Providers in `lib/features/<name>/presentation/providers/`

## Progress Tracking

### Feature Status
- [x] Tab Swipe Optimization - Decoupled PageView from GoRouter
- [x] Calendar Daily Income/Expense - DailySummary, marker bars, mini transaction rows
- [x] Budget Alert / Notifikasi - BudgetAlertService created, integrated into budget provider
- [x] Budget Rollover - Added rolloverAmount field to BudgetModel
- [x] Multi Currency - CurrencyModel, selector UI, CurrencyFormatter updated
- [x] Keinginan / Wishlist - New feature: wishlist with target, deadline, priority
- [x] Cash Flow Prediction 30 Hari - Rule-based prediction using 3-month average
- [x] Export Enhancement (PDF Print) - Print-to-printer using `printing` package
- [x] Backup & Restore Google Drive - Using Google Drive API
- [x] Scan QR for Transfer - Using mobile_scanner
- [x] Home Screen Widget Android - Basic widget showing balance

## Key Decisions
- Swipe uses local PageController state, no GoRouter involvement
- Calendar data sourced from existing income/expense lists via DailySummary
- Budget notifications use singleton with dedup sets
- Rollover handled as carry-over `rolloverAmount` on BudgetModel
- Multi currency stores selected currency in SharedPreferences
- Keinginan is a separate model from savings (different purpose)
- Prediction uses simple 3-month historical average (no ML)

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
- [x] Cash Flow Prediction 30 Hari - Rule-based prediction using 3-month average
- [x] Export Enhancement (PDF Print) - Print-to-printer using `printing` package
- [x] Backup & Restore Google Drive - Using Google Drive API
- [x] Home Screen Widget Android - Basic widget showing balance
- [x] Budget Daily Left Fix - Expense kategori "Tabungan" tidak mengurangi budget
- [x] Remove Unused Features - Wallet, QR Scanner, Wishlist dihapus (overlap & tidak terpakai)
- [x] Gold Investment in Goals - Tambah kategori "Investasi Emas" di Goals dengan tracking gram, harga beli/sekarang, profit/loss
- [x] Navbar 4 Tabs with Profile - Dashboard, Transactions, Budget, Profile (hapus dropdown profile dari AppBar)
- [x] Scan Struk & Bukti Transfer - OCR di HP (ML Kit), QRIS/struk -> pengeluaran, transfer masuk/gaji -> pemasukan
- [x] Impor Mutasi - screenshot mutasi -> hanya pemasukan dicentang; refund & pindah antar rekening sendiri diabaikan
- [x] Rekap Google Sheets - spreadsheet di Drive milik user sendiri (drive.file), tab per bulan + Ringkasan + grafik
- [x] Bagikan -> Family Finance - share gambar dari galeri/app bank langsung dibaca seperti scan
- [x] Back Android 14+ - sub-halaman (Tagihan/Utang/Tabungan) kembali ke Dashboard, tidak menutup app
- [x] Recurring anti-dobel - lewati periode yang sudah dicatat manual (kategori + nominal sama)
- [x] Tes struk belanja asli (kertas) & karcis parkir di HP user - aman
- [x] Goals berjangka (kontrakan/haji) - durasi, nabung per bulan, on track, ulang tiap tahun
- [x] Saldo goal dari screenshot bank - per kantong (Neo: Tabungan Neo / Neo NOW), cocok ke goal di bank yang sama
- [x] Sembunyikan nominal (ikon mata) di Home & Goals
- [x] Ingat saya di login - email disimpan app, password ke password manager HP
- [x] Profil gaya Telegram + sesi aktif (keluarkan perangkat lain) + ganti email
- [ ] Baca notifikasi bank (menunggu contoh notifikasi asli)
- [ ] OTP login (ditunda: berbayar) dan App Check

## Key Decisions
- Swipe uses local PageController state, no GoRouter involvement
- Calendar data sourced from existing income/expense lists via DailySummary
- Budget notifications use singleton with dedup sets
- Rollover handled as carry-over `rolloverAmount` on BudgetModel
- Multi currency stores selected currency in SharedPreferences
- Prediction uses simple 3-month historical average (no ML)
- **Daily Budget Left hanya track kategori yang ada di budget list**
- **Wallet, QR Scanner, Wishlist dihapus** - overlap dengan Goals/Savings, tidak diperlukan
- Income/Expense tidak lagi track walletId (simplified tracking)
- **Gold Investment** - extend Goals dengan kategori baru, track gram/harga/profit tanpa API (manual update)
- **Navbar 4 tabs** - Profile dipindah ke navbar tab keempat, dropdown menu dihapus dari AppBar
- **Goals Summary** - transaction history show all Tabungan/Savings expense (tidak filter by saving name)

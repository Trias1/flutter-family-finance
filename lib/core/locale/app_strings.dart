import 'package:flutter/widgets.dart';

class AppStrings {
  final Locale locale;

  const AppStrings(this.locale);

  bool get _id => locale.languageCode == 'id';

  String get dashboard => 'Dashboard';
  String get income => _id ? 'Pemasukan' : 'Income';
  String get expense => _id ? 'Pengeluaran' : 'Expense';
  String get transactions => _id ? 'Riwayat' : 'History';
  String get debts => _id ? 'Hutang' : 'Debts';
  String get wallets => _id ? 'Dompet' : 'Wallets';
  String get savings => 'Goals';
  String get budget => _id ? 'Anggaran' : 'Budget';
  String get reports => _id ? 'Laporan' : 'Reports';
  String get recurring => _id ? 'Berulang' : 'Recurring';
  String get categories => _id ? 'Kategori' : 'Categories';
  String get family => _id ? 'Keluarga' : 'Family';
  String get settings => _id ? 'Pengaturan' : 'Settings';
  String get privacySecurity =>
      _id ? 'Privasi & Keamanan' : 'Privacy & Security';
  String get profile => _id ? 'Profil' : 'Profile';
  String get completeGuide => _id ? 'Panduan Lengkap' : 'Complete Guide';
  String get user => _id ? 'Pengguna' : 'User';
  String get logout => _id ? 'Keluar' : 'Sign Out';
  String get security => _id ? 'Keamanan' : 'Security';
  String get fingerprint => _id ? 'Sidik jari' : 'Fingerprint';
  String get manageCategories => _id ? 'Kelola Kategori' : 'Manage Categories';
  String get backupRestore => _id ? 'Cadangan Data' : 'Backup';
  String get notifications => _id ? 'Notifikasi' : 'Notifications';
  String get appearance => _id ? 'Tampilan' : 'Appearance';
  String get darkMode => _id ? 'Mode Gelap' : 'Dark Mode';
  String get themeColor => _id ? 'Tema Warna' : 'Colour Theme';
  String get currency => _id ? 'Mata Uang' : 'Currency';
  String get on => _id ? 'Aktif' : 'On';
  String get off => _id ? 'Nonaktif' : 'Off';
  String get guideOpenFailed => _id
      ? 'Panduan tidak bisa dibuka. Cek koneksi atau browser di HP kamu.'
      : "Couldn't open the guide. Check your connection or browser.";
  String get later => _id ? 'Nanti' : 'Later';
  String get updateNow => _id ? 'Update Sekarang' : 'Update Now';
  String get requiredUpdateAvailable =>
      _id ? 'Update wajib tersedia' : 'Required update available';
  String get updateAvailable => _id ? 'Update tersedia' : 'Update available';
  String latestVersion(String version) =>
      _id ? 'Versi terbaru: $version' : 'Latest version: $version';
  String get updatePrivacyNote => _id
      ? 'Aplikasi hanya menyimpan info dasar perangkat untuk cek kompatibilitas dan update. Tidak mengambil kontak, lokasi, foto, file, nomor HP, atau IMEI.'
      : 'The app only stores basic device info for compatibility and update checks. It does not collect contacts, location, photos, files, phone number, or IMEI.';

  // Common actions and messages shared by feature pages.
  String get cancel => _id ? 'Batal' : 'Cancel';
  String get save => _id ? 'Simpan' : 'Save';
  String get delete => _id ? 'Hapus' : 'Delete';
  String get edit => 'Edit';
  String get add => _id ? 'Tambah' : 'Add';
  String get close => _id ? 'Tutup' : 'Close';
  String get yes => _id ? 'Ya' : 'Yes';
  String get retry => _id ? 'Coba lagi' : 'Try again';
  String get loading => _id ? 'Memuat...' : 'Loading...';
  String get loadFailed => _id
      ? 'Data belum bisa dimuat. Cek koneksi lalu coba lagi.'
      : "Couldn't load the data. Check your connection and try again.";
  String get saveFailed => _id
      ? 'Gagal menyimpan data. Coba lagi.'
      : "Couldn't save. Please try again.";
  String get deleteFailed => _id
      ? 'Gagal menghapus. Coba lagi.'
      : "Couldn't delete. Please try again.";
  String get actionFailed => _id
      ? 'Ada yang salah. Coba lagi ya.'
      : 'Something went wrong. Please try again.';
  String get requiredField => _id ? 'Wajib diisi' : 'Required';
  String get invalidAmount =>
      _id ? 'Masukkan nominal yang valid' : 'Enter a valid amount';
  String get daily => _id ? 'Harian' : 'Daily';
  String get weekly => _id ? 'Mingguan' : 'Weekly';
  String get monthly => _id ? 'Bulanan' : 'Monthly';
  String get yearly => _id ? 'Tahunan' : 'Yearly';
  String get other => _id ? 'Lainnya' : 'Other';

  String titleForRoute(String loc) {
    if (loc.startsWith('/income')) return income;
    if (loc.startsWith('/expense')) return expense;
    if (loc.startsWith('/transactions')) return transactions;
    if (loc.startsWith('/debts')) return debts;
    if (loc.startsWith('/wallets')) return wallets;
    if (loc.startsWith('/savings')) return savings;
    if (loc.startsWith('/budget/history')) {
      return _id ? 'Riwayat Anggaran' : 'Budget History';
    }
    if (loc.startsWith('/budget')) return budget;
    if (loc.startsWith('/reports')) return reports;
    if (loc.startsWith('/recurring')) return recurring;
    if (loc.startsWith('/dashboard-settings')) {
      return _id ? 'Atur Dashboard' : 'Customize Dashboard';
    }
    if (loc.startsWith('/categories')) return categories;
    if (loc.startsWith('/privacy-security')) return privacySecurity;
    if (loc.startsWith('/backup')) return backupRestore;
    if (loc.startsWith('/settings')) return settings;
    if (loc.startsWith('/family')) return family;
    return dashboard;
  }
}

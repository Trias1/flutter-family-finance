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

  String titleForRoute(String loc) {
    if (loc.startsWith('/income')) return income;
    if (loc.startsWith('/expense')) return expense;
    if (loc.startsWith('/transactions')) return transactions;
    if (loc.startsWith('/debts')) return debts;
    if (loc.startsWith('/wallets')) return wallets;
    if (loc.startsWith('/savings')) return savings;
    if (loc.startsWith('/budget')) return budget;
    if (loc.startsWith('/reports')) return reports;
    if (loc.startsWith('/recurring')) return recurring;
    if (loc.startsWith('/categories')) return categories;
    if (loc.startsWith('/privacy-security')) return privacySecurity;
    if (loc.startsWith('/settings')) return settings;
    if (loc.startsWith('/family')) return family;
    return dashboard;
  }
}

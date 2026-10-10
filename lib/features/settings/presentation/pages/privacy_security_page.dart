import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/locale/locale_provider.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';

/// Plain-language summary of how the app treats data. Every line here must
/// match what firestore.rules and the code actually do.
class PrivacySecurityPage extends ConsumerWidget {
  const PrivacySecurityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(localeProvider).languageCode == 'id';
    String t(String idText, String enText) => id ? idText : enText;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Header(
          title: t('Privasi & Keamanan', 'Privacy & Security'),
          body: t(
            'Cara Family Finance menjaga data kamu, tanpa bahasa hukum.',
            'How Family Finance looks after your data, in plain words.',
          ),
        ),
        const SizedBox(height: 16),
        _PrivacySection(
          icon: Icons.lock_rounded,
          title: t(
            'Data keuangan hanya untuk kamu',
            'Your finances stay yours',
          ),
          body: t(
            'Pemasukan, pengeluaran, hutang, tabungan, anggaran, kategori dan transaksi berulang hanya bisa dibaca akunmu sendiri, atau anggota keluarga yang satu grup denganmu. Aturan ini dijalankan di server, bukan cuma di aplikasi.',
            'Income, spending, debts, savings, budgets, categories and recurring entries can only be read by your account, or by members of the family you are in. The server enforces this, not just the app.',
          ),
        ),
        _PrivacySection(
          icon: Icons.groups_rounded,
          title: t(
            'Personal dan keluarga terpisah',
            'Personal and family are separate',
          ),
          body: t(
            'Sebelum bergabung ke keluarga, catatanmu ada di ruang pribadi. Setelah bergabung, catatan baru masuk ke ruang keluarga. Bergabung hanya bisa dengan kode undangan terbaru dari pemilik keluarga, dan anggota yang dikeluarkan tidak bisa masuk lagi.',
            'Before you join a family, your records live in a personal space. After you join, new records go to the family space. Joining needs the family owner\'s current invite code, and removed members cannot rejoin.',
          ),
        ),
        _PrivacySection(
          icon: Icons.admin_panel_settings_rounded,
          title: t(
            'Admin tidak melihat keuanganmu',
            'Admins cannot see your finances',
          ),
          body: t(
            'Panel admin hanya menampilkan nama pengguna dan info perangkat (merek, model, versi Android, versi aplikasi, waktu terakhir aktif yang diperbarui tiap menit selama aplikasi terbuka, dan token notifikasi untuk mengirim pemberitahuan update). Admin tidak bisa membaca data keuangan, email, atau data keluarga.',
            'The admin panel only shows usernames and device info (brand, model, Android version, app version, when you were last active (updated every minute while the app is open), and the notification token used to send update notices). Admins cannot read finance data, emails or family data.',
          ),
        ),
        _PrivacySection(
          icon: Icons.devices_rounded,
          title: t('Yang tidak kami ambil', 'What we do not collect'),
          body: t(
            'Aplikasi tidak mengambil kontak, lokasi, nomor HP, atau IMEI. Foto hanya dipakai kalau kamu sendiri memilih foto profil, dan disimpan di profilmu.',
            'The app does not collect contacts, location, phone number or IMEI. Photos are only used when you choose a profile picture yourself, and it is stored in your profile.',
          ),
        ),
        _PrivacySection(
          icon: Icons.fingerprint_rounded,
          title: t('Kunci sidik jari', 'Fingerprint lock'),
          body: t(
            'Kalau diaktifkan, aplikasi terkunci setiap kali dibuka dan setelah ditinggal lebih dari 1 menit. Isi aplikasi juga disembunyikan dari daftar aplikasi terbaru. Sidik jari diproses oleh sistem HP dan tidak pernah dikirim ke server.',
            'When on, the app locks every time it opens and after more than a minute away, and its content is hidden from the recent-apps screen. Your fingerprint is checked by the phone and never sent to a server.',
          ),
        ),
        _PrivacySection(
          icon: Icons.backup_rounded,
          title: t('Backup ada di tanganmu', 'Backups are in your hands'),
          body: t(
            'File backup dan backup Google Drive berisi data keuanganmu dan tidak dienkripsi. Simpan di tempat aman dan jangan dikirim ke orang lain.',
            'Backup files and Google Drive backups contain your finance data and are not encrypted. Keep them somewhere safe and do not send them to others.',
          ),
        ),
        _PrivacySection(
          icon: Icons.logout_rounded,
          title: t('Keluar dari akun', 'Signing out'),
          body: t(
            'Saat keluar, sesi login di HP ini dihapus. Kalau HP dipakai bersama, selalu keluar setelah selesai.',
            'Signing out ends the session on this phone. If you share the phone, always sign out when you are done.',
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String body;

  const _Header({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.privacy_tip_rounded,
            color: AppTheme.primaryColor,
            size: 28,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _PrivacySection({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

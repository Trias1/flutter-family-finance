import 'package:flutter/material.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';

class PrivacySecurityPage extends StatelessWidget {
  const PrivacySecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _HeaderCard(),
        SizedBox(height: 16),
        _PrivacySection(
          icon: Icons.lock_rounded,
          title: 'Data keuangan kamu privat',
          body:
              'Data pemasukan, pengeluaran, dompet, hutang, tabungan, budget, kategori, dan transaksi berulang hanya bisa dibaca oleh akun kamu sendiri atau anggota keluarga yang sedang satu grup dengan kamu.',
        ),
        _PrivacySection(
          icon: Icons.person_rounded,
          title: 'Mode Personal dan Keluarga terpisah',
          body:
              'Kalau kamu belum bergabung ke keluarga, data finance disimpan di ruang personal. Kalau kamu bergabung ke keluarga, data baru masuk ke ruang keluarga supaya anggota keluarga bisa kolaborasi.',
        ),
        _PrivacySection(
          icon: Icons.admin_panel_settings_rounded,
          title: 'Superadmin tidak melihat data finance',
          body:
              'Dashboard admin web hanya untuk monitoring username, device basic, platform, versi aplikasi, dan status update. Admin tidak diberi akses rules untuk membaca data keuangan, email pribadi, atau data keluarga member.',
        ),
        _PrivacySection(
          icon: Icons.devices_rounded,
          title: 'Info perangkat minimum',
          body:
              'Aplikasi menyimpan info perangkat dasar seperti brand, model, versi Android, versi aplikasi, dan last seen untuk pengecekan update. Aplikasi tidak mengambil kontak, lokasi, foto, file, nomor HP, atau IMEI.',
        ),
        _PrivacySection(
          icon: Icons.fingerprint_rounded,
          title: 'Biometric tetap lokal',
          body:
              'Fingerprint/biometric diproses oleh sistem perangkat. Aplikasi tidak menyimpan sidik jari kamu di server.',
        ),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.privacy_tip_rounded, color: Colors.white, size: 36),
          SizedBox(height: 12),
          Text(
            'Privasi & Keamanan',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Ringkasan cara Family Finance menjaga data kamu tetap aman dan terpisah.',
            style: TextStyle(color: Colors.white70, height: 1.4),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
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

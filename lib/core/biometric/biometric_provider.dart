import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

final localAuthProvider = Provider<LocalAuthentication>((ref) => LocalAuthentication());

final biometricEnabledProvider = StateNotifierProvider<BiometricNotifier, bool>((ref) {
  return BiometricNotifier();
});

Future<String> _effectiveBioKey() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid != null) return 'biometric_enabled_$uid';
  final prefs = await SharedPreferences.getInstance();
  final lastUid = prefs.getString('biometric_last_uid');
  if (lastUid != null) return 'biometric_enabled_$lastUid';
  return 'biometric_enabled';
}

class BiometricNotifier extends StateNotifier<bool> {
  BiometricNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final key = await _effectiveBioKey();
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(key) ?? false;
  }

  Future<String?> toggle() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final localAuth = LocalAuthentication();

    try {
      final isAvailable = await localAuth.canCheckBiometrics;
      final isSupported = await localAuth.isDeviceSupported();
      if (!isAvailable || !isSupported) return 'Perangkat tidak mendukung fingerprint';

      if (!state) {
        final authenticated = await localAuth.authenticate(
          localizedReason: 'Verifikasi sidik jari untuk mengaktifkan',
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
          ),
        );
        if (!authenticated) return 'Verifikasi dibatalkan';
      }
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains(auth_error.notEnrolled)) {
        return 'Belum ada sidik jari terdaftar. Daftarkan dulu di Pengaturan HP';
      }
      if (msg.contains(auth_error.notAvailable)) {
        return 'Fingerprint tidak tersedia di perangkat ini';
      }
      return 'Gagal: $msg';
    }

    state = !state;
    final prefs = await SharedPreferences.getInstance();
    final key = await _effectiveBioKey();
    await prefs.setBool(key, state);
    if (uid != null) await prefs.setString('biometric_last_uid', uid);
    return null;
  }
}

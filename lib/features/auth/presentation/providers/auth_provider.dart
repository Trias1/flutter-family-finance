import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/data/datasources/firebase_auth_datasource.dart';
import 'package:family_finance_manager/data/datasources/firestore_datasource.dart';
import 'package:family_finance_manager/data/models/family_model.dart';
import 'package:family_finance_manager/data/models/user_model.dart';
import 'package:family_finance_manager/data/repositories/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

final firebaseAuthDataSourceProvider = Provider<FirebaseAuthDataSource>((ref) {
  return FirebaseAuthDataSource();
});

final firestoreDataSourceProvider = Provider<FirestoreDataSource>((ref) {
  return FirestoreDataSource();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    authDataSource: ref.watch(firebaseAuthDataSourceProvider),
    firestoreDataSource: ref.watch(firestoreDataSourceProvider),
  );
});

// userChanges (not authStateChanges) so a verified email is noticed at once.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthDataSourceProvider).userChanges;
});

/// Email/password accounts must verify their address first (the Firestore
/// rules require it too). Google accounts are verified by Google.
bool needsEmailVerification(User user) =>
    !user.emailVerified &&
    user.providerData.any((p) => p.providerId == 'password');

final familyIdProvider = Provider<String>((ref) {
  final user = ref.watch(authNotifierProvider).valueOrNull;
  return user?.familyId ?? '';
});

final financeScopeIdProvider = Provider<String>((ref) {
  final user = ref.watch(authNotifierProvider).valueOrNull;
  if (user == null) return '';
  return user.familyId?.isNotEmpty == true ? user.familyId! : user.id;
});

final familyProvider = FutureProvider<FamilyModel?>((ref) async {
  final familyId = ref.watch(familyIdProvider);
  if (familyId.isEmpty) return null;
  final dataSource = ref.watch(firestoreDataSourceProvider);
  final family = await dataSource.getFamily(familyId);
  final uid = ref.watch(authNotifierProvider).valueOrNull?.id;
  if (family != null && family.createdBy == uid) {
    // Older families have no invite doc yet; without it nobody can join.
    unawaited(dataSource.ensureFamilyInvite(family).catchError((_) {}));
  }
  return family;
});

final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final auth = ref.watch(firebaseAuthDataSourceProvider);
  final user = auth.currentUser;
  if (user == null) return null;
  final repo = ref.watch(authRepositoryProvider);
  try {
    return await repo.getUser(user.uid);
  } catch (_) {
    return null;
  }
});

class AuthNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final AuthRepository _authRepository;

  AuthNotifier(this._authRepository) : super(const AsyncValue.data(null));

  /// Loads the profile for an already signed-in Firebase user, e.g. after an
  /// app restart or a biometric unlock.
  Future<void> restoreSession(String uid) async {
    try {
      final user = await _authRepository.getUser(uid);
      if (mounted) state = AsyncValue.data(user);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  /// Keeps the profile in step with Firebase Auth: cleared on sign-out,
  /// reloaded when a different (or restored) user is signed in.
  void syncWithFirebase(String? uid) {
    if (uid == null) {
      state = const AsyncValue.data(null);
    } else if (state.valueOrNull?.id != uid && !state.isLoading) {
      restoreSession(uid);
    }
  }

  Future<String?> signInWithEmail(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _authRepository.signInWithEmail(email, password);
      state = AsyncValue.data(user);
      return null;
    } catch (e) {
      final msg = _getAuthErrorMessage(e);
      state = AsyncValue.error(msg, StackTrace.current);
      return msg;
    }
  }

  Future<String?> signUpWithEmail(
    String name,
    String email,
    String password,
  ) async {
    state = const AsyncValue.loading();
    try {
      final user = await _authRepository.signUpWithEmail(
        name: name,
        email: email,
        password: password,
      );
      state = AsyncValue.data(user);
      return null;
    } catch (e) {
      final msg = _getAuthErrorMessage(e);
      state = AsyncValue.error(msg, StackTrace.current);
      return msg;
    }
  }

  Future<String?> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final user = await _authRepository.signInWithGoogle();
      state = AsyncValue.data(user);
      return null;
    } catch (e) {
      final msg = _getAuthErrorMessage(e);
      state = AsyncValue.error(msg, StackTrace.current);
      return msg;
    }
  }

  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _authRepository.sendPasswordResetEmail(email);
      return null;
    } catch (e) {
      return _getAuthErrorMessage(e);
    }
  }

  Future<String?> updateProfile({String? name, String? photoUrl}) async {
    try {
      await _authRepository.updateProfile(name: name, photoUrl: photoUrl);
      final uid = _authRepository.currentUser?.uid;
      if (uid != null) {
        final updated = await _authRepository.getUser(uid);
        if (updated != null) state = AsyncValue.data(updated);
      }
      return null;
    } catch (e) {
      return _getAuthErrorMessage(e);
    }
  }

  Future<String?> joinFamily(
    String familyId, {
    String? familyName,
    String role = 'member',
    String? joinCode,
  }) async {
    try {
      await _authRepository.updateFamilyId(
        familyId,
        familyName: familyName,
        role: role,
        joinCode: joinCode,
      );
      final uid = _authRepository.currentUser?.uid;
      if (uid != null) {
        final updated = await _authRepository.getUser(uid);
        if (updated != null) state = AsyncValue.data(updated);
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> leaveFamily({String? newOwnerId}) async {
    try {
      await _authRepository.leaveFamily(newOwnerId: newOwnerId);
      final uid = _authRepository.currentUser?.uid;
      if (uid != null) {
        final updated = await _authRepository.getUser(uid);
        if (updated != null) state = AsyncValue.data(updated);
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> kickMember(String targetUid, {String? fromFamilyId}) async {
    try {
      await _authRepository.kickMember(targetUid, fromFamilyId: fromFamilyId);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> changePassword(
    String newPassword, {
    String? currentPassword,
  }) async {
    try {
      await _authRepository.changePassword(
        newPassword,
        currentPassword: currentPassword,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      // Here the user is already signed in, so naming the wrong field is safe.
      if (e.code == 'wrong-password' ||
          e.code == 'invalid-credential' ||
          e.code == 'invalid-login-credentials') {
        return 'Password saat ini salah';
      }
      if (e.code == 'requires-recent-login') {
        return 'Demi keamanan, keluar lalu masuk lagi sebelum mengganti password';
      }
      return _getAuthErrorMessage(e);
    } catch (e) {
      return _getAuthErrorMessage(e);
    }
  }

  Future<void> signOut({bool keepGoogleSession = false}) async {
    await _authRepository.signOut(keepGoogleSession: keepGoogleSession);
    state = const AsyncValue.data(null);
  }

  String _getAuthErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        // One message for every credential failure, so the app never
        // reveals whether an email is registered.
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
        case 'invalid-login-credentials':
          return 'Email atau password salah';
        case 'email-already-in-use':
          return 'Akun tidak bisa dibuat dengan email ini. Jika sudah punya akun, silakan masuk atau reset password';
        case 'too-many-requests':
          return 'Terlalu banyak percobaan. Coba lagi nanti';
        case 'network-request-failed':
          return 'Tidak ada koneksi internet';
        case 'weak-password':
        // Server-side password policy (8+ characters with a number).
        case 'password-does-not-meet-requirements':
          return 'Password minimal 8 karakter, berisi huruf dan angka';
        case 'invalid-email':
          return 'Email tidak valid';
        default:
          return 'Terjadi kesalahan. Silakan coba lagi';
      }
    }
    return 'Terjadi kesalahan. Silakan coba lagi';
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>((ref) {
      final notifier = AuthNotifier(ref.watch(authRepositoryProvider));
      ref.listen<AsyncValue<User?>>(
        authStateProvider,
        (_, next) => notifier.syncWithFirebase(next.valueOrNull?.uid),
        fireImmediately: true,
      );
      return notifier;
    });

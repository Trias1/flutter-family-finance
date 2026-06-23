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

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthDataSourceProvider).authStateChanges;
});

final familyIdProvider = Provider<String>((ref) {
  final user = ref.watch(authNotifierProvider).valueOrNull;
  return user?.familyId ?? '';
});

final financeScopeIdProvider = Provider<String>((ref) {
  final user = ref.watch(authNotifierProvider).valueOrNull;
  if (user == null) return '';
  return user.familyId?.isNotEmpty == true ? user.familyId! : user.id;
});

final familyProvider = FutureProvider<FamilyModel?>((ref) {
  final familyId = ref.watch(familyIdProvider);
  if (familyId.isEmpty) return Future.value(null);
  return ref.watch(firestoreDataSourceProvider).getFamily(familyId);
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
  }) async {
    try {
      await _authRepository.updateFamilyId(
        familyId,
        familyName: familyName,
        role: role,
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

  Future<String?> leaveFamily() async {
    try {
      await _authRepository.leaveFamily();
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

  Future<String?> changePassword(String newPassword) async {
    try {
      await _authRepository.changePassword(newPassword);
      return null;
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
        case 'user-not-found':
          return 'Email tidak terdaftar';
        case 'wrong-password':
          return 'Password salah';
        case 'invalid-credential':
          return 'Email atau password salah';
        case 'email-already-in-use':
          return 'Email sudah digunakan';
        case 'too-many-requests':
          return 'Terlalu banyak percobaan. Coba lagi nanti';
        case 'network-request-failed':
          return 'Tidak ada koneksi internet';
        case 'weak-password':
          return 'Password minimal 6 karakter';
        case 'invalid-email':
          return 'Email tidak valid';
        default:
          return 'Terjadi kesalahan. Silakan coba lagi';
      }
    }
    final message = error.toString();
    if (message.contains('User not found')) {
      return 'Akun tidak ditemukan. Silakan daftar dulu';
    }
    return 'Terjadi kesalahan. Silakan coba lagi';
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>((ref) {
      return AuthNotifier(ref.watch(authRepositoryProvider));
    });

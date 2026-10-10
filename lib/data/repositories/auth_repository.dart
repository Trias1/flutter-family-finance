import 'package:family_finance_manager/data/datasources/firebase_auth_datasource.dart';
import 'package:family_finance_manager/data/datasources/firestore_datasource.dart';
import 'package:family_finance_manager/data/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  final FirebaseAuthDataSource _authDataSource;
  final FirestoreDataSource _firestoreDataSource;

  AuthRepository({
    required FirebaseAuthDataSource authDataSource,
    required FirestoreDataSource firestoreDataSource,
  }) : _authDataSource = authDataSource,
       _firestoreDataSource = firestoreDataSource;

  Future<UserModel?> getUser(String uid) async {
    return _firestoreDataSource.getUser(uid);
  }

  Future<UserModel> signInWithEmail(String email, String password) async {
    final credential = await _authDataSource.signInWithEmail(email, password);
    final user = credential.user;
    if (user == null) throw Exception('User not found');
    var userModel = await _firestoreDataSource.getUser(user.uid);
    if (userModel == null) {
      userModel = UserModel(
        id: user.uid,
        name: user.displayName ?? email.split('@').first,
        email: email,
        photoUrl: user.photoURL,
      );
      await _firestoreDataSource.createUser(userModel);
    }
    return userModel;
  }

  Future<UserModel> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _authDataSource.signUpWithEmail(email, password);
    final user = credential.user;
    if (user == null) throw Exception('Failed to create user');
    await user.updateDisplayName(name);
    // Best effort: a failed send must not undo a successful sign-up.
    await user.sendEmailVerification().catchError((_) {});
    final userModel = UserModel(
      id: user.uid,
      name: name,
      email: email,
      photoUrl: user.photoURL,
    );
    await _firestoreDataSource.createUser(userModel);
    return userModel;
  }

  Future<UserModel> signInWithGoogle() async {
    final credential = await _authDataSource.signInWithGoogle();
    final user = credential.user;
    if (user == null) throw Exception('Failed to sign in with Google');
    var userModel = await _firestoreDataSource.getUser(user.uid);
    if (userModel == null) {
      userModel = UserModel(
        id: user.uid,
        name: user.displayName ?? '',
        email: user.email ?? '',
        photoUrl: user.photoURL,
      );
      await _firestoreDataSource.createUser(userModel);
    }
    return userModel;
  }

  Future<void> updateProfile({String? name, String? photoUrl}) async {
    final uid = _authDataSource.currentUser?.uid;
    if (uid == null) throw Exception('No user logged in');
    final isDataUri = photoUrl != null && photoUrl.startsWith('data:image/');
    if (!isDataUri) {
      await _authDataSource.updateProfile(
        displayName: name,
        photoUrl: photoUrl,
      );
    } else if (name != null) {
      await _authDataSource.updateProfile(displayName: name, photoUrl: null);
    }
    final user = await _firestoreDataSource.getUser(uid);
    if (user != null) {
      final updated = UserModel(
        id: user.id,
        name: name ?? user.name,
        email: user.email,
        photoUrl: photoUrl ?? user.photoUrl,
        familyId: user.familyId,
        familyHistory: user.familyHistory,
        role: user.role,
        createdAt: user.createdAt,
      );
      await _firestoreDataSource.updateUser(updated);
    }
  }

  Future<void> changePassword(String newPassword) {
    return _authDataSource.changePassword(newPassword);
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _authDataSource.sendPasswordResetEmail(email);
  }

  Future<void> updateFamilyId(
    String familyId, {
    String? familyName,
    String role = 'member',
    String? joinCode,
  }) async {
    final uid = _authDataSource.currentUser?.uid;
    if (uid == null) throw Exception('No user logged in');
    final user = await _firestoreDataSource.getUser(uid);
    if (user == null) throw Exception('User not found');
    final history = List<Map<String, String>>.from(user.familyHistory);
    final exists = history.any((h) => h['id'] == familyId);
    if (!exists && familyName != null) {
      history.add({'id': familyId, 'name': familyName});
    }
    final updated = UserModel(
      id: user.id,
      name: user.name,
      email: user.email,
      photoUrl: user.photoUrl,
      familyId: familyId,
      familyHistory: history,
      role: role,
      createdAt: user.createdAt,
    );
    await _firestoreDataSource.updateUser(updated, joinCode: joinCode);
  }

  Future<void> leaveFamily() async {
    final uid = _authDataSource.currentUser?.uid;
    if (uid == null) throw Exception('No user logged in');
    final user = await _firestoreDataSource.getUser(uid);
    if (user == null) throw Exception('User not found');
    final familyId = user.familyId;
    if (familyId != null && familyId.isNotEmpty) {
      final family = await _firestoreDataSource.getFamily(familyId);
      if (family != null && family.createdBy == uid) {
        final members = await _firestoreDataSource.getUsersByFamilyId(familyId);
        final others = members.where((m) => m.id != uid).toList();
        if (others.isNotEmpty) {
          await _firestoreDataSource.transferFamilyOwnership(
            familyId,
            others.first.id,
          );
        }
      }
    }
    final updated = UserModel(
      id: user.id,
      name: user.name,
      email: user.email,
      photoUrl: user.photoUrl,
      familyId: null,
      familyHistory: user.familyHistory,
      role: 'member',
      createdAt: user.createdAt,
    );
    await _firestoreDataSource.updateUser(updated);
  }

  Future<void> kickMember(String targetUid, {String? fromFamilyId}) async {
    final user = await _firestoreDataSource.getUser(targetUid);
    if (user == null) throw Exception('User not found');
    if (fromFamilyId != null && user.familyId != fromFamilyId) {
      throw Exception('User tidak dalam keluarga ini');
    }
    await _firestoreDataSource.removeFamilyMember(targetUid);
  }

  Future<void> signOut({bool keepGoogleSession = false}) =>
      _authDataSource.signOut(keepGoogleSession: keepGoogleSession);

  User? get currentUser => _authDataSource.currentUser;

  Stream<User?> get authStateChanges => _authDataSource.authStateChanges;
}

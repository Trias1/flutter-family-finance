import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

/// Account deletion runs on the server (it removes data across collections
/// and the Auth user), shared with the web app.
const accountDeleteEndpoint =
    'https://finance.west-solutions.web.id/api/account/delete';

class FirebaseAuthDataSource {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signUpWithEmail(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign in cancelled');
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> updateProfile({String? displayName, String? photoUrl}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');
    if (displayName != null) await user.updateDisplayName(displayName);
    if (photoUrl != null) await user.updatePhotoURL(photoUrl);
  }

  /// With [currentPassword], proves the user knows it before changing it
  /// (also satisfies Firebase's "recent login" requirement).
  Future<void> changePassword(
    String newPassword, {
    String? currentPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');
    if (currentPassword != null) {
      final email = user.email;
      if (email == null) {
        throw FirebaseAuthException(code: 'no-password-account');
      }
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: currentPassword),
      );
    }
    await user.updatePassword(newPassword);
  }

  Future<void> signOut({bool keepGoogleSession = false}) async {
    await _auth.signOut();
    if (!keepGoogleSession) {
      await _googleSignIn.signOut();
    }
    await clearLocalData();
  }

  /// Removes the offline Firestore cache so the next person on this phone
  /// cannot read the previous account's finance data from disk.
  Future<void> clearLocalData() async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.terminate();
      await firestore.clearPersistence();
    } catch (_) {
      // The cache is cleared on the next start if this was interrupted.
    }
  }

  bool get hasPasswordProvider =>
      _auth.currentUser?.providerData.any((p) => p.providerId == 'password') ??
      false;

  /// Fresh sign-in proof required before deleting the account.
  /// Sends a confirmation link to [newEmail]; the sign-in email changes only
  /// once that link is opened, so a typo cannot lock the account. Needs the
  /// current password first.
  Future<void> requestEmailChange(String newEmail, String password) async {
    await reauthenticate(password: password);
    await _auth.currentUser!.verifyBeforeUpdateEmail(newEmail.trim());
  }

  Future<void> reauthenticate({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'no-current-user');
    if (hasPasswordProvider) {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: user.email ?? '',
          password: password ?? '',
        ),
      );
      return;
    }
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw FirebaseAuthException(code: 'cancelled');
    final googleAuth = await googleUser.authentication;
    await user.reauthenticateWithCredential(
      GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      ),
    );
  }

  /// Returns null on success, otherwise the server's error code.
  Future<String?> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return 'unauthenticated';
    final token = await user.getIdToken(true);
    final res = await http
        .post(
          Uri.parse(accountDeleteEndpoint),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'confirm': 'DELETE'}),
        )
        .timeout(const Duration(seconds: 60));
    if (res.statusCode == 200) {
      await signOut();
      return null;
    }
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['code'] is String) return body['code'] as String;
    } catch (_) {}
    return 'server';
  }

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Also fires after reload(), e.g. when the email becomes verified.
  Stream<User?> get userChanges => _auth.userChanges();
}

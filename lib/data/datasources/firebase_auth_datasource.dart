import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
  }

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Also fires after reload(), e.g. when the email becomes verified.
  Stream<User?> get userChanges => _auth.userChanges();
}

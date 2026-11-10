import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'guest_progress_snapshot.dart';

/// Firebase Authentication girişlerini tek noktadan yönetir.
/// Yerel misafir ilerlemesi bu servis tarafından silinmez veya sıfırlanmaz.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static bool get isAvailable => Firebase.apps.isNotEmpty;
  static Stream<User?> get authStateChanges =>
      FirebaseAuth.instance.authStateChanges();
  User? get currentUser =>
      isAvailable ? FirebaseAuth.instance.currentUser : null;

  Future<UserCredential?> signInWithGoogle() async {
    if (!isAvailable) {
      throw FirebaseAuthException(
        code: 'auth-not-configured',
        message: 'Firebase Authentication is not configured.',
      );
    }
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null;
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return FirebaseAuth.instance.signInWithCredential(credential);
  }

  Future<UserCredential> signInWithEmail(String email, String password) {
    return FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> createAccount(String email, String password) {
    return FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Uploads guest progress on first sign-in and restores/merges it on
  /// subsequent devices. The merge uses high-water marks to avoid counting
  /// the same local progress twice.
  Future<void> syncProgressForCurrentUser() async {
    final user = currentUser;
    if (user == null) return;
    final document = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('private')
        .doc('progress');
    final local = GuestProgressSnapshot.capture();
    final remoteDocument = await document.get();
    final combined = remoteDocument.exists
        ? GuestProgressSnapshot.merge(
            local,
            GuestProgressSnapshot.fromMap(remoteDocument.data()!),
          )
        : local;
    await document.set({
      ...combined.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await combined.applyToLocal();
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    try {
      await GoogleSignIn().signOut();
    } catch (_) {
      // E-posta hesabıyla girişte Google oturumu bulunmayabilir.
    }
  }
}

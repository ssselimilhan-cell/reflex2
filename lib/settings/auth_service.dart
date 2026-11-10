import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool get isAdmin => currentUser?.email?.trim().toLowerCase() == 'ssselimilhan@gmail.com' && currentUser?.emailVerified == true;

  Future<UserCredential?> signInWithGoogle() async {
    if (!isAvailable) {
      throw FirebaseAuthException(
        code: 'auth-not-configured',
        message: 'Firebase Authentication is not configured.',
      );
    }
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;
      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        throw FirebaseAuthException(
          code: 'google-token-missing',
          message: 'Google oturumundan kimlik bilgisi alınamadı.',
        );
      }
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await FirebaseAuth.instance.signInWithCredential(credential);
    } on FirebaseAuthException {
      rethrow;
    } catch (error) {
      throw FirebaseAuthException(
        code: 'google-sign-in-configuration-error',
        message: 'Google ile giriş yapılandırması başarısız: $error',
      );
    }
  }

  Future<UserCredential> signInWithEmail(String email, String password) {
    return FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> createAccount(String email, String password) async {
    final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    // E-posta doğrulaması admin yetkisi için zorunlu; hesap açılışında
    // kullanıcıya doğrulama bağlantısını otomatik gönder.
    await credential.user?.sendEmailVerification();
    return credential;
  }

  Future<void> resendVerificationEmail() async {
    final user = currentUser;
    if (user == null || user.emailVerified) return;
    await user.sendEmailVerification();
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
    final preferences = await SharedPreferences.getInstance();
    final previousUid = preferences.getString('accountProgressUid');
    final switchedAccount = previousUid != null && previousUid != user.uid;
    final local = GuestProgressSnapshot.capture();
    final remoteDocument = await document.get();
    final remote = remoteDocument.exists
        ? GuestProgressSnapshot.fromMap(remoteDocument.data()!)
        : null;
    final combined = remote != null
        ? (switchedAccount
            ? remote
            : GuestProgressSnapshot.merge(local, remote))
        : (switchedAccount ? GuestProgressSnapshot.empty() : local);
    await document.set({
      ...combined.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await combined.applyToLocal();
    await preferences.setString('accountProgressUid', user.uid);
  }

  Future<void> signOut() async {
    await syncProgressForCurrentUser();
    await FirebaseAuth.instance.signOut();
    try {
      await GoogleSignIn().signOut();
    } catch (_) {
      // E-posta hesabıyla girişte Google oturumu bulunmayabilir.
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'guest_progress_snapshot.dart';
import 'user_profile.dart';

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
  bool get isAdmin {
    final user = currentUser;
    if (user?.email?.trim().toLowerCase() != 'ssselimilhan@gmail.com') return false;
    final googleVerified = user!.providerData.any((provider) => provider.providerId == 'google.com');
    return user.emailVerified || googleVerified;
  }

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
      final result = await FirebaseAuth.instance.signInWithCredential(credential);
      await UserProfile.instance.activateAccountProfile()
          .timeout(const Duration(seconds: 8));
      return result;
    } on FirebaseAuthException {
      rethrow;
    } catch (error) {
      throw FirebaseAuthException(
        code: 'google-sign-in-configuration-error',
        message: 'Google ile giriş yapılandırması başarısız: $error',
      );
    }
  }

  Future<UserCredential> signInWithEmail(String email, String password) async {
    final result = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    await UserProfile.instance.activateAccountProfile()
        .timeout(const Duration(seconds: 8));
    return result;
  }

  Future<UserCredential> createAccount(String email, String password) async {
    if (password.length < 6) {
      throw FirebaseAuthException(
        code: 'weak-password',
        message: 'Şifre en az 6 karakter olmalı.',
      );
    }
    final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    // Hesap oluşturma başarılı olduktan sonra doğrulama e-postası gönderimi
    // ayrı bir ağ işlemi olabilir. Gönderim başarısızsa hesabı başarısız
    // göstermeyiz; profil kartından yeniden gönderilebilir.
    try {
      await credential.user?.sendEmailVerification();
    } catch (_) {
      // Authentication hesabı oluşturuldu; kullanıcı yeniden gönderebilir.
    }
    await UserProfile.instance.activateAccountProfile()
        .timeout(const Duration(seconds: 8));
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
    // Oturum kapatma, Firestore erişimine bağlı olmamalı. Önce ilerlemeyi
    // kısa süreliğine senkronize etmeyi dene; ağ/izin hatası çıkarsa çıkışı
    // engelleme.
    try {
      await syncProgressForCurrentUser().timeout(const Duration(seconds: 2));
    } catch (_) {
      // Çevrimdışı veya Firestore erişimi yok: oturumu yine de kapat.
    }

    // Firebase oturumunu Google SDK temizliğinden önce kapat. Böylece
    // GoogleSignIn.signOut() hata verse bile uygulama misafir durumuna geçer.
    await FirebaseAuth.instance.signOut();
    await UserProfile.instance.activateGuestProfile()
        .timeout(const Duration(seconds: 3));
    try {
      await GoogleSignIn().signOut().timeout(const Duration(seconds: 2));
    } catch (_) {
      // Firebase oturumu zaten kapatıldı; yerel Google oturumu sonraki
      // Google girişinde yeniden yetkilendirilebilir.
    }
  }
}

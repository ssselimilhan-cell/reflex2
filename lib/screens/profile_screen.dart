import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../settings/app_settings.dart';
import '../settings/user_profile.dart';
import '../settings/strings.dart';
import '../widgets/profile_avatar.dart';
import '../settings/moderation.dart';
import '../settings/ranks.dart';
import '../settings/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  bool _saving = false;
  bool _authBusy = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    if (!await ensureTermsAccepted(context)) return;
    if (!mounted) return;
    setState(() => _saving = true);
    await UserProfile.instance.createProfile(name);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([AppSettings.instance, UserProfile.instance]),
      builder: (context, _) {
        final profile = UserProfile.instance;
        return Scaffold(
          backgroundColor: AppSettings.instance.themeColor,
          appBar: AppBar(
            title: Text(t('profile'), style: const TextStyle(fontWeight: FontWeight.w800)),
            backgroundColor: const Color(0xFF142238),
            foregroundColor: Colors.white,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              child: profile.hasProfile
                  ? _buildProfileView(profile)
                  : _buildCreateView(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAccountCard() {
    if (!AuthService.isAvailable) {
      return const SizedBox.shrink();
    }
    return StreamBuilder(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        final user = snapshot.data;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1B293D),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x55FBBF24)),
          ),
          child: user != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      CircleAvatar(
                        backgroundColor: user.emailVerified
                            ? const Color(0x2234D399) : const Color(0x33FBBF24),
                        child: Icon(
                          user.emailVerified ? Icons.verified_user : Icons.mark_email_unread_rounded,
                          color: user.emailVerified ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.emailVerified ? t('account_connected') : 'E-posta doğrulaması bekleniyor',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text(user.email ?? user.displayName ?? user.uid,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: t('sign_out'),
                        onPressed: _authBusy ? null : _signOut,
                        icon: const Icon(Icons.logout, color: Colors.white70),
                      ),
                    ]),
                    if (user.email != null && !user.emailVerified) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Hesabını ve yönetici ayrıcalıklarını etkinleştirmek için e-posta bağlantısını onayla.',
                        style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _authBusy ? null : _resendVerification,
                          icon: const Icon(Icons.mark_email_read_rounded, size: 17),
                          label: const Text('Doğrulama e-postasını yeniden gönder'),
                          style: TextButton.styleFrom(foregroundColor: const Color(0xFFFBBF24)),
                        ),
                      ),
                    ],
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(t('account_title'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Text(t('account_guest_hint'),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12, height: 1.4)),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _authBusy ? null : _signInWithGoogle,
                      icon: const Icon(Icons.g_mobiledata, size: 25),
                      label: Text(t('continue_google')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0x88FBBF24)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: _authBusy ? null : _signInWithEmail,
                      icon: const Icon(Icons.email_outlined),
                      label: Text(t('continue_email')),
                      style: FilledButton.styleFrom(
                        foregroundColor: const Color(0xFF101827),
                        backgroundColor: const Color(0xFFFBBF24),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    if (_authBusy)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _authBusy = true);
    try {
      final credential = await AuthService.instance.signInWithGoogle();
      if (!mounted) return;
      if (credential != null) {
        try {
          await AuthService.instance.syncProgressForCurrentUser();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t('account_connected'))),
            );
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t('account_sync_pending'))),
            );
          }
        }
      }
    } catch (error) {
      if (mounted) _showAuthError(error);
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  Future<void> _signInWithEmail() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    var createAccount = false;
    final choice = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1B293D),
          title: Text(createAccount ? t('create_account') : t('sign_in'),
              style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: t('email'),
                  labelStyle: const TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: t('password'),
                  labelStyle: const TextStyle(color: Colors.white70),
                ),
              ),
              TextButton(
                onPressed: () =>
                    setDialogState(() => createAccount = !createAccount),
                child: Text(
                  createAccount ? t('already_have_account') : t('need_account'),
                  style: const TextStyle(color: Color(0xFF60A5FA)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, createAccount),
              child: Text(createAccount ? t('create_account') : t('sign_in')),
            ),
          ],
        ),
      ),
    );
    final email = emailController.text.trim();
    final password = passwordController.text;
    emailController.dispose();
    passwordController.dispose();
    if (choice == null) return;
    final emailLooksValid = email.contains('@') &&
        email.substring(email.indexOf('@') + 1).contains('.') &&
        !email.contains(' ');
    if (!emailLooksValid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('auth_invalid_email'))),
        );
      }
      return;
    }
    if (password.isEmpty || (choice && password.length < 6)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(choice ? 'Şifre en az 6 karakter olmalı.' : t('auth_invalid_credentials'))),
        );
      }
      return;
    }
    setState(() => _authBusy = true);
    try {
      if (choice) {
        await AuthService.instance.createAccount(email, password);
      } else {
        await AuthService.instance.signInWithEmail(email, password);
      }
      try {
        await AuthService.instance.syncProgressForCurrentUser();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(choice
              ? 'Hesap oluşturuldu. E-posta adresine gönderdiğimiz doğrulama bağlantısını onayla.'
              : t('account_connected'))),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t('account_sync_pending'))),
          );
        }
      }
    } catch (error) {
      if (mounted) _showAuthError(error);
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  Future<void> _resendVerification() async {
    setState(() => _authBusy = true);
    try {
      await AuthService.instance.resendVerificationEmail();
      await FirebaseAuth.instance.currentUser?.reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Doğrulama bağlantısı yeniden gönderildi. Gelen kutunu ve spam klasörünü kontrol et.')),
        );
        setState(() {});
      }
    } catch (error) {
      if (mounted) _showAuthError(error);
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _authBusy = true);
    try {
      await AuthService.instance.signOut();
    } catch (error) {
      if (mounted) _showAuthError(error);
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  void _showAuthError(Object error) {
    final message = error is FirebaseAuthException
        ? switch (error.code) {
            'email-already-in-use' => t('auth_email_exists'),
            'invalid-email' => t('auth_invalid_email'),
            'weak-password' => t('auth_weak_password'),
            'user-not-found' || 'wrong-password' || 'invalid-credential' =>
              t('auth_invalid_credentials'),
            'network-request-failed' => t('auth_network_error'),
            'operation-not-allowed' => 'Bu giriş yöntemi Firebase Console > Authentication > Sign-in method bölümünde etkinleştirilmemiş.',
            'app-not-authorized' || 'invalid-api-key' => 'Firebase Android uygulama yapılandırması/API anahtarı uyuşmuyor. Paket adı ve google-services.json kontrol edilmeli.',
            'unauthorized-domain' => 'Bu uygulama alan adı Firebase Authentication için yetkilendirilmemiş.',
            'google-sign-in-configuration-error' || 'google-token-missing' => 'Google girişi Firebase tarafında tamamlanmamış. Google sağlayıcısı, SHA-1/SHA-256 parmak izleri ve Android OAuth istemcisi yapılandırılmalı. Ayrıntı: ${error.message ?? error.code}',
            _ => '${error.code}: ${error.message ?? t('auth_error')}',
          }
        : error.toString();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildCreateView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAccountCard(),
        const SizedBox(height: 20),
        Text(t('create_profile'),
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(t('guest_playing'),
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0x22FBBF24),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x55FBBF24)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: Color(0xFFFBBF24), size: 19),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  t('guest_data_warning'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _nameController,
          maxLength: 20,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: InputDecoration(
            labelText: t('display_name'),
            labelStyle: const TextStyle(color: Colors.white70),
            hintText: t('enter_name_hint'),
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white54),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(t('save')),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('play_as_guest'),
              style: const TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }

  Widget _buildProfileView(UserProfile profile) {
    final rate = profile.onlineWinRate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAccountCard(),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF29415F), Color(0xFF17263A), Color(0xFF111D2E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0x66FBBF24)),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 9)),
            ],
          ),
          child: Column(children: [
            Row(children: [
              GestureDetector(
                onTap: () => _showAvatarPicker(context),
                child: Stack(clipBehavior: Clip.none, children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xCCFBBF24), width: 2),
                    ),
                    child: const ProfileAvatar(radius: 34),
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(color: Color(0xFFFBBF24), shape: BoxShape.circle),
                      child: const Icon(Icons.edit_rounded, size: 12, color: Color(0xFF101827)),
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 15),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.displayName!,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text(t('online_win_rate').toUpperCase(),
                    style: const TextStyle(color: Colors.white60, fontSize: 10, letterSpacing: 1.1, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(rate == null ? t('no_games_yet') : '${rate.round()}%',
                    style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 30, fontWeight: FontWeight.w900)),
                ],
              )),
            ]),
            const SizedBox(height: 18),
            Container(height: 1, color: Colors.white12),
            const SizedBox(height: 13),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _ProfileMetric(label: t('games_played'), value: profile.onlineGamesPlayed, icon: Icons.style_rounded),
              _ProfileMetric(label: t('wins'), value: profile.onlineWins, icon: Icons.emoji_events_rounded),
              _ProfileMetric(label: t('losses'), value: profile.onlineLosses, icon: Icons.trending_down_rounded),
            ]),
          ]),
        ),
        const SizedBox(height: 22),
        
        _RankCard(wins: profile.onlineWins),
        const SizedBox(height: 28),
        Padding(
          // Buton tam ekran kenarına yapışmasın diye biraz yukarı alındı.
          // (Spacer() yerine sabit boşluk — kaydırılabilir ekranla uyumlu
          // olsun diye; Spacer sınırsız yükseklikte hataya yol açardı.)
          padding: const EdgeInsets.only(bottom: 8),
          child: OutlinedButton(
            onPressed: () async {
              await UserProfile.instance.deleteProfile();
            },
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
            child: Text(t('delete_profile')),
          ),
        ),
      ],
    );
  }

  Future<void> _pickFromGallery(BuildContext sheetContext) async {
    try {
      final picker = ImagePicker();
      // NOT: Küçük boyut/kalite bilinçli seçildi — bu fotoğraf sadece
      // küçük dairesel avatar olarak gösterileceği için, hem cihazda hem
      // Firestore'a senkronize edilen sürümde aynı (küçük) dosya
      // kullanılıyor. Böylece rakip de bu fotoğrafı görebiliyor.
      final xfile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 300,
        maxHeight: 300,
        imageQuality: 70,
      );
      if (xfile == null) return; // kullanıcı vazgeçti
      final bytes = await xfile.readAsBytes();
      final dir = await getApplicationDocumentsDirectory();
      final savedPath =
          '${dir.path}/profile_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(savedPath).writeAsBytes(bytes);
      final base64Data = base64Encode(bytes);
      await UserProfile.instance.setPhoto(savedPath, base64Data);
      if (sheetContext.mounted) Navigator.pop(sheetContext);
    } catch (e) {
      if (sheetContext.mounted) {
        ScaffoldMessenger.of(sheetContext).showSnackBar(
          SnackBar(content: Text('Fotoğraf seçilemedi: $e')),
        );
      }
    }
  }

  void _showAvatarPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B1B1B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return AnimatedBuilder(
          animation: UserProfile.instance,
          builder: (context, _) {
            final profile = UserProfile.instance;
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('choose_avatar'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _pickFromGallery(sheetContext),
                      icon: const Icon(Icons.photo_library),
                      label: Text(t('choose_from_gallery')),
                    ),
                  ),
                  if (profile.photoPath != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextButton(
                        onPressed: () => profile.clearPhoto(),
                        child: Text(t('remove_photo'),
                            style: const TextStyle(color: Colors.white54)),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: List.generate(kAvatarIcons.length, (i) {
                      final selected = profile.avatarIconIndex == i;
                      return GestureDetector(
                        onTap: () =>
                            profile.setAvatar(i, profile.avatarColor),
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: selected
                              ? profile.avatarColor
                              : profile.avatarColor.withOpacity(0.4),
                          child: Icon(kAvatarIcons[i],
                              color: Colors.white,
                              size: selected ? 26 : 22),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  Text(t('settings_color'),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    children: AppSettings.presetColors.map((c) {
                      final selected = c.value == profile.avatarColor.value;
                      return GestureDetector(
                        onTap: () =>
                            profile.setAvatar(profile.avatarIconIndex, c),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  selected ? Colors.white : Colors.white24,
                              width: selected ? 3 : 1,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ProfileMetric extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;

  const _ProfileMetric({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Icon(icon, color: const Color(0xFFFBBF24), size: 17),
      const SizedBox(height: 5),
      Text('$value', style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
      const SizedBox(height: 2),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: FittedBox(fit: BoxFit.scaleDown, child: Text(label,
          style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w600))),
      ),
    ]),
  );
}

/// Rütbe rozeti ve sonraki rütbeye ilerleme çubuğu.
class _RankCard extends StatelessWidget {
  final int wins;
  const _RankCard({required this.wins});

  @override
  Widget build(BuildContext context) {
    final r = rankFor(wins);
    final next = nextRankFor(wins);
    final progress = next == null
        ? 1.0
        : ((wins - r.minWins) / (next.minWins - r.minWins))
            .clamp(0.0, 1.0)
            .toDouble();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(r.emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t(r.nameKey),
                    style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.white12,
                  color: Colors.amber,
                ),
                if (next != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    t('next_rank_hint')
                        .replaceAll('{name}', t(next.nameKey))
                        .replaceAll('{n}', '${next.minWins - wins}'),
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
).hasMatch(email)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('auth_invalid_email'))),
        );
      }
      return;
    }
    if (password.isEmpty || (choice && password.length < 6)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(choice ? 'Şifre en az 6 karakter olmalı.' : t('auth_invalid_credentials'))),
        );
      }
      return;
    }

    setState(() => _authBusy = true);
    try {
      if (choice) {
        await AuthService.instance.createAccount(email, password);
      } else {
        await AuthService.instance.signInWithEmail(email, password);
      }
      try {
        await AuthService.instance.syncProgressForCurrentUser();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(choice
              ? 'Hesap oluşturuldu. E-posta adresine gönderdiğimiz doğrulama bağlantısını onayla.'
              : t('account_connected'))),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t('account_sync_pending'))),
          );
        }
      }
    } catch (error) {
      if (mounted) _showAuthError(error);
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _authBusy = true);
    try {
      await AuthService.instance.signOut();
    } catch (error) {
      if (mounted) _showAuthError(error);
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  void _showAuthError(Object error) {
    final message = error is FirebaseAuthException
        ? switch (error.code) {
            'email-already-in-use' => t('auth_email_exists'),
            'invalid-email' => t('auth_invalid_email'),
            'weak-password' => t('auth_weak_password'),
            'user-not-found' || 'wrong-password' || 'invalid-credential' =>
              t('auth_invalid_credentials'),
            'network-request-failed' => t('auth_network_error'),
            'operation-not-allowed' => 'Bu giriş yöntemi Firebase Console > Authentication > Sign-in method bölümünde etkinleştirilmemiş.',
            'app-not-authorized' || 'invalid-api-key' => 'Firebase Android uygulama yapılandırması/API anahtarı uyuşmuyor. Paket adı ve google-services.json kontrol edilmeli.',
            'unauthorized-domain' => 'Bu uygulama alan adı Firebase Authentication için yetkilendirilmemiş.',
            'google-sign-in-configuration-error' || 'google-token-missing' => 'Google girişi Firebase tarafında tamamlanmamış. Google sağlayıcısı, SHA-1/SHA-256 parmak izleri ve Android OAuth istemcisi yapılandırılmalı. Ayrıntı: ${error.message ?? error.code}',
            _ => '${error.code}: ${error.message ?? t('auth_error')}',
          }
        : error.toString();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildCreateView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAccountCard(),
        const SizedBox(height: 20),
        Text(t('create_profile'),
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(t('guest_playing'),
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0x22FBBF24),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x55FBBF24)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: Color(0xFFFBBF24), size: 19),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  t('guest_data_warning'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _nameController,
          maxLength: 20,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: InputDecoration(
            labelText: t('display_name'),
            labelStyle: const TextStyle(color: Colors.white70),
            hintText: t('enter_name_hint'),
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white54),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(t('save')),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('play_as_guest'),
              style: const TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }

  Widget _buildProfileView(UserProfile profile) {
    final rate = profile.onlineWinRate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAccountCard(),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF29415F), Color(0xFF17263A), Color(0xFF111D2E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0x66FBBF24)),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 9)),
            ],
          ),
          child: Column(children: [
            Row(children: [
              GestureDetector(
                onTap: () => _showAvatarPicker(context),
                child: Stack(clipBehavior: Clip.none, children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xCCFBBF24), width: 2),
                    ),
                    child: const ProfileAvatar(radius: 34),
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(color: Color(0xFFFBBF24), shape: BoxShape.circle),
                      child: const Icon(Icons.edit_rounded, size: 12, color: Color(0xFF101827)),
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 15),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.displayName!,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text(t('online_win_rate').toUpperCase(),
                    style: const TextStyle(color: Colors.white60, fontSize: 10, letterSpacing: 1.1, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(rate == null ? t('no_games_yet') : '${rate.round()}%',
                    style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 30, fontWeight: FontWeight.w900)),
                ],
              )),
            ]),
            const SizedBox(height: 18),
            Container(height: 1, color: Colors.white12),
            const SizedBox(height: 13),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _ProfileMetric(label: t('games_played'), value: profile.onlineGamesPlayed, icon: Icons.style_rounded),
              _ProfileMetric(label: t('wins'), value: profile.onlineWins, icon: Icons.emoji_events_rounded),
              _ProfileMetric(label: t('losses'), value: profile.onlineLosses, icon: Icons.trending_down_rounded),
            ]),
          ]),
        ),
        const SizedBox(height: 22),
        
        _RankCard(wins: profile.onlineWins),
        const SizedBox(height: 28),
        Padding(
          // Buton tam ekran kenarına yapışmasın diye biraz yukarı alındı.
          // (Spacer() yerine sabit boşluk — kaydırılabilir ekranla uyumlu
          // olsun diye; Spacer sınırsız yükseklikte hataya yol açardı.)
          padding: const EdgeInsets.only(bottom: 8),
          child: OutlinedButton(
            onPressed: () async {
              await UserProfile.instance.deleteProfile();
            },
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
            child: Text(t('delete_profile')),
          ),
        ),
      ],
    );
  }

  Future<void> _pickFromGallery(BuildContext sheetContext) async {
    try {
      final picker = ImagePicker();
      // NOT: Küçük boyut/kalite bilinçli seçildi — bu fotoğraf sadece
      // küçük dairesel avatar olarak gösterileceği için, hem cihazda hem
      // Firestore'a senkronize edilen sürümde aynı (küçük) dosya
      // kullanılıyor. Böylece rakip de bu fotoğrafı görebiliyor.
      final xfile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 300,
        maxHeight: 300,
        imageQuality: 70,
      );
      if (xfile == null) return; // kullanıcı vazgeçti
      final bytes = await xfile.readAsBytes();
      final dir = await getApplicationDocumentsDirectory();
      final savedPath =
          '${dir.path}/profile_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(savedPath).writeAsBytes(bytes);
      final base64Data = base64Encode(bytes);
      await UserProfile.instance.setPhoto(savedPath, base64Data);
      if (sheetContext.mounted) Navigator.pop(sheetContext);
    } catch (e) {
      if (sheetContext.mounted) {
        ScaffoldMessenger.of(sheetContext).showSnackBar(
          SnackBar(content: Text('Fotoğraf seçilemedi: $e')),
        );
      }
    }
  }

  void _showAvatarPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B1B1B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return AnimatedBuilder(
          animation: UserProfile.instance,
          builder: (context, _) {
            final profile = UserProfile.instance;
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('choose_avatar'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _pickFromGallery(sheetContext),
                      icon: const Icon(Icons.photo_library),
                      label: Text(t('choose_from_gallery')),
                    ),
                  ),
                  if (profile.photoPath != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextButton(
                        onPressed: () => profile.clearPhoto(),
                        child: Text(t('remove_photo'),
                            style: const TextStyle(color: Colors.white54)),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: List.generate(kAvatarIcons.length, (i) {
                      final selected = profile.avatarIconIndex == i;
                      return GestureDetector(
                        onTap: () =>
                            profile.setAvatar(i, profile.avatarColor),
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: selected
                              ? profile.avatarColor
                              : profile.avatarColor.withOpacity(0.4),
                          child: Icon(kAvatarIcons[i],
                              color: Colors.white,
                              size: selected ? 26 : 22),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  Text(t('settings_color'),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    children: AppSettings.presetColors.map((c) {
                      final selected = c.value == profile.avatarColor.value;
                      return GestureDetector(
                        onTap: () =>
                            profile.setAvatar(profile.avatarIconIndex, c),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  selected ? Colors.white : Colors.white24,
                              width: selected ? 3 : 1,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ProfileMetric extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;

  const _ProfileMetric({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Icon(icon, color: const Color(0xFFFBBF24), size: 17),
      const SizedBox(height: 5),
      Text('$value', style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
      const SizedBox(height: 2),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: FittedBox(fit: BoxFit.scaleDown, child: Text(label,
          style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w600))),
      ),
    ]),
  );
}

/// Rütbe rozeti ve sonraki rütbeye ilerleme çubuğu.
class _RankCard extends StatelessWidget {
  final int wins;
  const _RankCard({required this.wins});

  @override
  Widget build(BuildContext context) {
    final r = rankFor(wins);
    final next = nextRankFor(wins);
    final progress = next == null
        ? 1.0
        : ((wins - r.minWins) / (next.minWins - r.minWins))
            .clamp(0.0, 1.0)
            .toDouble();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(r.emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t(r.nameKey),
                    style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.white12,
                  color: Colors.amber,
                ),
                if (next != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    t('next_rank_hint')
                        .replaceAll('{name}', t(next.nameKey))
                        .replaceAll('{n}', '${next.minWins - wins}'),
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

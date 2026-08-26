import 'package:flutter/material.dart';
import 'local_pvp_screen.dart';
import 'vs_bot_screen.dart';
import 'online_lobby_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import '../main.dart';
import '../settings/app_settings.dart';
import '../settings/user_profile.dart';
import '../settings/strings.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([AppSettings.instance, UserProfile.instance]),
      builder: (context, _) {
        final profile = UserProfile.instance;
        return Scaffold(
          backgroundColor: AppSettings.instance.themeColor,
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        t('app_title'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4),
                      ),
                      const SizedBox(height: 4),
                      Text(t('app_subtitle'),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 16)),
                      const SizedBox(height: 48),
                      _MenuButton(
                        label: t('menu_local'),
                        icon: Icons.people,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const LocalPvpScreen())),
                      ),
                      const SizedBox(height: 16),
                      _MenuButton(
                        label: t('menu_bot'),
                        icon: Icons.smart_toy,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const VsBotScreen())),
                      ),
                      const SizedBox(height: 16),
                      _MenuButton(
                        label: t('menu_online'),
                        icon: Icons.wifi,
                        onTap: () {
                          if (!firebaseAvailable) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(t('firebase_needed'))),
                            );
                            return;
                          }
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const OnlineLobbyScreen()));
                        },
                      ),
                      const SizedBox(height: 16),
                      _MenuButton(
                        label: t('menu_settings'),
                        icon: Icons.settings,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SettingsScreen())),
                      ),
                    ],
                  ),
                ),
                // Sağ üst köşede profil özeti / oluşturma girişi
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ProfileScreen())),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              profile.hasProfile
                                  ? '${profile.displayName!}'
                                      '${profile.onlineWinRate != null ? ' · ${profile.onlineWinRate!.round()}%' : ''}'
                                  : t('create_profile'),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _MenuButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppSettings.instance.themeColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

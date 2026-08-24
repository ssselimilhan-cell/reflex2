import 'package:flutter/material.dart';
import 'local_pvp_screen.dart';
import 'vs_bot_screen.dart';
import 'online_lobby_screen.dart';
import 'settings_screen.dart';
import '../main.dart';
import '../settings/app_settings.dart';
import '../settings/strings.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppSettings.instance.themeColor,
          body: Center(
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
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 16)),
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
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const VsBotScreen())),
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

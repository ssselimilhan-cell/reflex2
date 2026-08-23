import 'package:flutter/material.dart';
import 'local_pvp_screen.dart';
import 'vs_bot_screen.dart';
import 'online_lobby_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B6E4F),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'STRES',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4),
            ),
            const SizedBox(height: 4),
            const Text('Refleks Kart Oyunu',
                style: TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 48),
            _MenuButton(
              label: '2 Kişilik (Aynı Cihaz)',
              icon: Icons.people,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LocalPvpScreen())),
            ),
            const SizedBox(height: 16),
            _MenuButton(
              label: 'Bilgisayara Karşı',
              icon: Icons.smart_toy,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const VsBotScreen())),
            ),
            const SizedBox(height: 16),
            _MenuButton(
              label: 'Online Oyna',
              icon: Icons.wifi,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const OnlineLobbyScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _MenuButton({required this.label, required this.icon, required this.onTap});

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
          foregroundColor: const Color(0xFF0B6E4F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

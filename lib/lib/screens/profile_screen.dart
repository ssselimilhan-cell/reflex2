import 'package:flutter/material.dart';
import '../settings/app_settings.dart';
import '../settings/user_profile.dart';
import '../settings/strings.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
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
          appBar: AppBar(title: Text(t('profile'))),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: profile.hasProfile
                ? _buildProfileView(profile)
                : _buildCreateView(),
          ),
        );
      },
    );
  }

  Widget _buildCreateView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t('create_profile'),
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(t('guest_playing'),
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
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
        Row(
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white24,
              child: Icon(Icons.person, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                profile.displayName!,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Text(t('online_win_rate'),
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          rate == null ? t('no_games_yet') : '${rate.round()}%',
          style: const TextStyle(
              color: Colors.amber, fontSize: 40, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _StatBox(label: t('games_played'), value: profile.onlineGamesPlayed),
            const SizedBox(width: 12),
            _StatBox(label: t('wins'), value: profile.onlineWins),
            const SizedBox(width: 12),
            _StatBox(label: t('losses'), value: profile.onlineLosses),
          ],
        ),
        const Spacer(),
        OutlinedButton(
          onPressed: () async {
            await UserProfile.instance.deleteProfile();
          },
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
          child: Text(t('delete_profile')),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final int value;

  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text('$value',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

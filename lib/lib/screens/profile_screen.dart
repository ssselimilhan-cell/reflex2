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
            GestureDetector(
              onTap: () => _showAvatarPicker(context),
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: profile.avatarColor,
                    child: Icon(kAvatarIcons[profile.avatarIconIndex],
                        color: Colors.white, size: 30),
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.edit,
                          size: 12, color: profile.avatarColor),
                    ),
                  ),
                ],
              ),
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
        Padding(
          // Buton tam ekran kenarına yapışmasın diye biraz yukarı alındı.
          padding: const EdgeInsets.only(bottom: 32),
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

import 'package:flutter/material.dart';
import '../online/firestore_game_repository.dart';
import '../online/persistent_device_id.dart';
import '../settings/app_settings.dart';
import '../settings/user_profile.dart';
import '../settings/strings.dart';
import 'online_game_screen.dart';

class OnlineLobbyScreen extends StatefulWidget {
  const OnlineLobbyScreen({super.key});

  @override
  State<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends State<OnlineLobbyScreen> {
  final _repo = OnlineRoomRepository();
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;

  /// Profil ile aynı, cihazda KALICI kimlik — oturum bazlı değil,
  /// böylece profil senkronizasyonuyla tutarlı kalır.
  Future<String> _deviceId() async =>
      UserProfile.instance.deviceId ?? await getPersistentDeviceId();

  Future<void> _createRoom() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final deviceId = await _deviceId();
      final code = await _repo.createRoom(deviceId);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OnlineGameScreen(
            roomCode: code,
            deviceId: deviceId,
            isHost: true,
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = 'Oda oluşturulamadı: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinRoom() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final deviceId = await _deviceId();
      final ok = await _repo.joinRoom(code, deviceId);
      if (!ok) {
        setState(() => _error = t('room_not_found'));
        return;
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OnlineGameScreen(
            roomCode: code,
            deviceId: deviceId,
            isHost: false,
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = 'Katılınamadı: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppSettings.instance.themeColor,
          appBar: AppBar(title: Text(t('menu_online'))),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _loading ? null : _createRoom,
                    child: Text(t('new_room')),
                  ),
                  const SizedBox(height: 32),
                  Text(t('or'), style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _codeController,
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 24, letterSpacing: 6),
                    maxLength: 4,
                    decoration: InputDecoration(
                      hintText: t('room_code_hint'),
                      hintStyle: const TextStyle(color: Colors.white38),
                      counterText: '',
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white54),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loading ? null : _joinRoom,
                    child: Text(t('join_room')),
                  ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: CircularProgressIndicator(),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(_error!,
                          style: const TextStyle(color: Colors.redAccent)),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

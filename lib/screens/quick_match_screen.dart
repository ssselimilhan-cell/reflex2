import 'package:flutter/material.dart';
import '../settings/telemetry.dart';
import 'quick_match_session.dart';
import 'vs_bot_screen.dart';
import 'online_game_screen.dart';

class QuickMatchScreen extends StatefulWidget {
  const QuickMatchScreen({super.key});

  @override
  State<QuickMatchScreen> createState() => _QuickMatchScreenState();
}

class _QuickMatchScreenState extends State<QuickMatchScreen> {
  final _session = QuickMatchSession();
  bool _launched = false;

  @override
  void initState() {
    super.initState();
    Telemetry.log('quick_match_start');
    _session.start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _launched) return;
      _launched = true;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VsBotScreen(
            autoStart: true,
            onGameFinished: _finishAndTransition,
            onAbandon: _session.cancel,
          ),
        ),
      );
    });
  }

  Future<void> _finishAndTransition() async {
    final match = await _session.finish();
    if (!mounted || match == null) return;
    Telemetry.log('quick_match_found_after_bot', {'host': match.isHost});
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OnlineGameScreen(
          roomCode: match.roomCode,
          deviceId: match.deviceId,
          isHost: match.isHost,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: Color(0xFF101827),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Color(0xFF22D3EE)),
          SizedBox(height: 16),
          Text('Rakip aranıyor…', style: TextStyle(color: Colors.white70)),
          SizedBox(height: 6),
          Text('Bu sırada bot maçın başlıyor.', style: TextStyle(color: Colors.white54)),
        ],
      ),
    ),
  );
}

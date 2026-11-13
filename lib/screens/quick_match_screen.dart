import 'package:flutter/material.dart';
import '../settings/telemetry.dart';
import '../settings/strings.dart';
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
  bool _transitioning = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    Telemetry.log('quick_match_start');
    _session.start();
    _session.matchFound.then(_handleMatch);
  }

  Future<void> _handleMatch(QuickMatchResult? match) async {
    if (!mounted || _transitioning) return;
    if (match == null) {
      setState(() => _failed = true);
      return;
    }
    _transitioning = true;
    final confirmed = await _session.finish();
    if (!mounted || confirmed == null) return;
    Telemetry.log('quick_match_found', {'host': confirmed.isHost});
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OnlineGameScreen(
          roomCode: confirmed.roomCode,
          deviceId: confirmed.deviceId,
          isHost: confirmed.isHost,
        ),
      ),
    );
  }

  Future<void> _playBotInstead() async {
    if (_transitioning) return;
    _transitioning = true;
    await _session.cancel();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const VsBotScreen(autoStart: true)),
    );
  }

  Future<void> _cancelSearch() async {
    if (_transitioning) return;
    _transitioning = true;
    await _session.cancel();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB94E20),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1B2A40),
              Color(0xFF101827),
              Color(0xFF0B1220),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 112,
                              height: 112,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFFBBF24).withOpacity(.10),
                                border: Border.all(
                                  color: const Color(0xFFFBBF24).withOpacity(.35),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFBBF24).withOpacity(.12),
                                    blurRadius: 34,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.groups_rounded,
                                color: Color(0xFFFBBF24),
                                size: 54,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              _failed ? t('qm_search_failed') : t('qm_searching'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _failed
                                  ? t('qm_search_failed_hint')
                                  : t('qm_waiting_hint'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 26),
                            if (!_failed)
                              const SizedBox(
                                width: 34,
                                height: 34,
                                child: CircularProgressIndicator(
                                  color: Color(0xFFFBBF24),
                                  strokeWidth: 3,
                                ),
                              ),
                            const SizedBox(height: 30),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _failed
                                    ? () {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const QuickMatchScreen(),
                                          ),
                                        );
                                      }
                                    : _playBotInstead,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFBBF24),
                                  foregroundColor: const Color(0xFF101827),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 15,
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _failed
                                          ? Icons.refresh_rounded
                                          : Icons.smart_toy_outlined,
                                    ),
                                    const SizedBox(width: 10),
                                    Flexible(
                                      child: Text(
                                        _failed ? t('retry') : t('qm_play_bot_now'),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        softWrap: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: _cancelSearch,
                              child: Text(
                                t('qm_cancel'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (!_transitioning) _session.cancel();
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import '../settings/app_settings.dart';
import '../settings/strings.dart';
import '../settings/telemetry.dart';
import '../widgets/game_demo_animation.dart';
import 'vs_bot_screen.dart';

/// İlk açılışta bir kez gösterilen kısa eğitim (ve Oyun Kuralları ekranından
/// tekrar açılabilir). Son sayfada kolay bir botla ilk oyun başlatılabilir.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _pageCount = 4;
  final _controller = PageController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    Telemetry.log('onboarding_shown');
    // Bir kez gösterilsin: yarıda bırakılsa bile bir daha otomatik açılmaz.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppSettings.instance.setOnboardingDone(true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _playFirstGame() {
    Telemetry.log('onboarding_first_game');
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) =>
          const VsBotScreen(autoStart: true, initialDifficulty: 0.2),
    ));
  }

  Widget _page(String emoji, String titleKey, String bodyKey, Widget? extra) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 14),
          Text(t(titleKey),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(t(bodyKey),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 15, height: 1.45)),
          if (extra != null) ...[const SizedBox(height: 18), extra],
        ],
      ),
    );
  }

  Widget _streakRow(String left, String right) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text('$left   ➜   $right',
            style: const TextStyle(
                color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold)),
      );

  @override
  Widget build(BuildContext context) {
    final last = _page == _pageCount - 1;
    return Scaffold(
      backgroundColor: AppSettings.instance.themeColor,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(t('ob_skip'),
                    style: const TextStyle(color: Colors.white70)),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _page('👀', 'ob1_title', 'ob1_body', const GameDemoAnimation()),
                  _page('🏁', 'ob2_title', 'ob2_body', null),
                  _page(
                    '🔥',
                    'ob3_title',
                    'ob3_body',
                    Column(children: [
                      _streakRow('3', '🔥 +1'),
                      _streakRow('5', '🎉 +2'),
                      _streakRow('8', '🏆 +3'),
                    ]),
                  ),
                  _page('🚀', 'ob4_title', 'ob4_body', null),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pageCount,
                (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _page ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _page ? Colors.amber : Colors.white30,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 18, 28, 22),
              child: last
                  ? Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _playFirstGame,
                            icon: const Icon(Icons.play_arrow),
                            label: Text(t('ob_play_first'),
                                style: const TextStyle(fontSize: 16)),
                            style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14)),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(t('ob_to_menu'),
                              style: const TextStyle(color: Colors.white70)),
                        ),
                      ],
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut),
                        style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: Text(t('ob_next'),
                            style: const TextStyle(fontSize: 16)),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'local_pvp_screen.dart';
import 'vs_bot_screen.dart';
import 'online_lobby_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import 'rules_screen.dart';
import 'leaderboard_screen.dart';
import 'quick_match_screen.dart';
import 'onboarding_screen.dart';
import 'ladder_screen.dart';
import 'star_shop_screen.dart';
import '../models/playing_card.dart';
import '../widgets/card_widget.dart';
import '../widgets/daily_card.dart';
import '../widgets/game_ui.dart';
import '../widgets/profile_avatar.dart';
import '../settings/moderation.dart';
import '../main.dart';
import '../settings/app_settings.dart';
import '../settings/ladder.dart';
import '../settings/progress.dart';
import '../settings/user_profile.dart';
import '../settings/strings.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _openQuickMatch(BuildContext context) async {
    if (!firebaseAvailable) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const VsBotScreen(autoStart: true)));
      return;
    }
    if (!await ensureTermsAccepted(context)) return;
    if (!context.mounted) return;
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const QuickMatchScreen()));
  }

  Future<void> _openOnline(BuildContext context) async {
    if (!firebaseAvailable) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('firebase_needed'))));
      return;
    }
    if (!await ensureTermsAccepted(context)) return;
    if (!context.mounted) return;
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const OnlineLobbyScreen()));
  }

  Future<void> _openLeaderboard(BuildContext context) async {
    if (!firebaseAvailable) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('firebase_needed'))));
      return;
    }
    if (!await ensureTermsAccepted(context)) return;
    if (!context.mounted) return;
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const LeaderboardScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        AppSettings.instance,
        UserProfile.instance,
        Progress.instance,
        LadderProgress.instance,
      ]),
      builder: (context, _) {
        final settings = AppSettings.instance;
        final ladder = LadderProgress.instance;
        return Scaffold(
          backgroundColor: settings.themeColor,
          body: Stack(
            children: [
              Positioned.fill(child: FeltBackground(base: settings.themeColor)),
              const _OnboardingTrigger(),
              SafeArea(
                child: Column(
                  children: [
                    _TopBar(
                      onShop: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StarShopScreen())),
                      onProfile: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ProfileScreen())),
                      onSettings: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SettingsScreen())),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final contentWidth = constraints.maxWidth < 552
                              ? constraints.maxWidth
                              : 520.0;
                          return Center(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: SizedBox(
                                width: contentWidth,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                const Reveal(index: 0, child: _Hero()),
                                const SizedBox(height: 8),
                                Reveal(
                                  index: 1,
                                  child: GamePrimaryButton(
                                    label: t('menu_quick_match'),
                                    subtitle: t('tile_quick_sub'),
                                    icon: Icons.bolt_rounded,
                                    height: 76,
                                    pulse: true,
                                    onTap: () => _openQuickMatch(context),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Reveal(
                                  index: 2,
                                  child: IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: GameTile(
                                            title: t('menu_ladder'),
                                            subtitle:
                                                '${t('level')} ${ladder.unlockedLevel}',
                                            icon: Icons.smart_toy,
                                            accent: GameUi.goldDeep,
                                            footer: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: ladder.highestCleared /
                                                    LadderProgress.maxLevel,
                                                minHeight: 5,
                                                backgroundColor:
                                                    const Color(0x33FFFFFF),
                                                valueColor:
                                                    const AlwaysStoppedAnimation<
                                                        Color>(GameUi.gold),
                                              ),
                                            ),
                                            onTap: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        const LadderScreen())),
                                          ),
                                        ),
                                        const SizedBox(width: 9),
                                        Expanded(
                                          child: GameTile(
                                            title: t('menu_online'),
                                            subtitle: t('tile_online_sub'),
                                            icon: Icons.public,
                                            accent: GameUi.gold,
                                            onTap: () => _openOnline(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Reveal(
                                  index: 3,
                                  child: IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: GameTile(
                                            title: t('menu_local'),
                                            subtitle: t('tile_local_sub'),
                                            icon: Icons.people,
                                            accent: GameUi.goldDeep,
                                            onTap: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        const LocalPvpScreen())),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: GameTile(
                                            title: t('menu_leaderboard'),
                                            subtitle: t('tile_board_sub'),
                                            icon: Icons.leaderboard,
                                            accent: GameUi.rewardGold,
                                            onTap: () =>
                                                _openLeaderboard(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Reveal(index: 4, child: DailyCard()),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    _RulesBar(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const RulesScreen())),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Üst çubuk: solda profil hapı, sağda yıldız sayısı ve ayarlar.
class _TopBar extends StatelessWidget {
  final VoidCallback onProfile;
  final VoidCallback onSettings;
  final VoidCallback onShop;

  const _TopBar({required this.onProfile, required this.onSettings, required this.onShop});

  @override
  Widget build(BuildContext context) {
    final profile = UserProfile.instance;
    final rate = profile.onlineWinRate;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Flexible(
            child: Material(
              color: Colors.transparent,
              child: Ink(
                decoration: BoxDecoration(
                  color: GameUi.glass,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: GameUi.hairline),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: onProfile,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (profile.hasProfile)
                          const ProfileAvatar(radius: 15)
                        else
                          const CircleAvatar(
                            radius: 15,
                            backgroundColor: Color(0x33FFFFFF),
                            child: Icon(Icons.person,
                                color: Colors.white, size: 18),
                          ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            profile.hasProfile
                                ? profile.displayName!
                                : t('create_profile'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (profile.hasProfile && rate != null) ...[
                          const SizedBox(width: 8),
                          Text('${rate.round()}%',
                              style: GameUi.display(13, color: GameUi.gold)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Spacer(),
          GamePill(
            leading:
                const Icon(Icons.star_rounded, color: GameUi.gold, size: 20),
            text: '${Progress.instance.stars}',
            onTap: onShop,
          ),
          const SizedBox(width: 10),
          GameIconButton(
            icon: Icons.settings,
            tooltip: t('menu_settings'),
            onTap: onSettings,
          ),
        ],
      ),
    );
  }
}

/// Logo ve üstünde hafifçe süzülen, eşleşen iki kartı gösteren yelpaze.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 4),
        _CardFan(),
        SizedBox(height: 6),
        GameLogo(),
      ],
    );
  }
}

class _CardFan extends StatefulWidget {
  const _CardFan();

  @override
  State<_CardFan> createState() => _CardFanState();
}

class _CardFanState extends State<_CardFan>
    with TickerProviderStateMixin {
  final math.Random _random = math.Random();
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);

  late final List<AnimationController> _glows = List.generate(3, (_) {
    final controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 650 + _random.nextInt(1250)),
      value: _random.nextDouble(),
    );
    controller.repeat(reverse: true);
    return controller;
  });

  @override
  void dispose() {
    _c.dispose();
    for (final glow in _glows) {
      glow.dispose();
    }
    super.dispose();
  }

  Widget _card(PlayingCard card, double angle, Offset offset,
      {required int glowIndex}) {
    return Transform.translate(
      offset: offset,
      child: Transform.rotate(
        angle: angle,
        child: AnimatedBuilder(
          animation: _glows[glowIndex],
          builder: (context, _) => CardWidget(
            card: card,
            highlighted: _glows[glowIndex].value > 0.48,
            width: 66,
            height: 94,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final v = Curves.easeInOut.transform(_c.value);
          return SizedBox(
            height: 128,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _card(const PlayingCard(Suit.spades, 13), -0.30 + v * 0.04,
                    Offset(-62, 10 - v * 3), glowIndex: 0),
                _card(const PlayingCard(Suit.hearts, 7), 0.30 - v * 0.04,
                    Offset(62, 10 + v * 3), glowIndex: 1),
                _card(const PlayingCard(Suit.diamonds, 7), 0,
                    Offset(0, -4 + v * 5), glowIndex: 2),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RulesBar extends StatelessWidget {
  final VoidCallback onTap;
  const _RulesBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x33000000),
      child: SafeArea(
        top: false,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.menu_book, color: Colors.white70, size: 19),
                const SizedBox(width: 8),
                Text(
                  t('rules_title'),
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ana ekran açıldığında, eğitim daha önce gösterilmediyse bir kez açar.
class _OnboardingTrigger extends StatefulWidget {
  const _OnboardingTrigger();

  @override
  State<_OnboardingTrigger> createState() => _OnboardingTriggerState();
}

class _OnboardingTriggerState extends State<_OnboardingTrigger> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || AppSettings.instance.onboardingDone) return;
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const OnboardingScreen()));
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

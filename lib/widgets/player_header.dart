import 'package:flutter/material.dart';
import 'game_ui.dart';

class PlayerHeader extends StatelessWidget {
  final Widget avatar;
  final String name;
  final int stockCount;
  final bool showCount;

  const PlayerHeader({
    super.key,
    required this.avatar,
    required this.name,
    required this.stockCount,
    this.showCount = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xCC1B293D), Color(0x99101B2C)],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: GameUi.hairline),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          avatar,
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              name,
              maxLines: 2,
              softWrap: true,
              overflow: TextOverflow.fade,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.12,
                letterSpacing: 0.25,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (showCount) ...[
            const SizedBox(width: 10),
            StockCountBadge(count: stockCount),
          ],
        ],
      ),
    );
  }
}

class StockCountBadge extends StatelessWidget {
  final int count;
  final Color numberColor;

  const StockCountBadge({
    super.key,
    required this.count,
    this.numberColor = GameUi.cyan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: GameUi.primary.withOpacity(0.20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GameUi.cyan.withOpacity(0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.style_rounded, color: Colors.white70, size: 14),
          const SizedBox(width: 5),
          Text('$count',
              style: TextStyle(color: numberColor, fontWeight: FontWeight.w900, fontSize: 16)),
        ],
      ),
    );
  }
}

class StockCountsBar extends StatelessWidget {
  final int leftCount;
  final int rightCount;
  final String leftLabel;
  final String rightLabel;

  const StockCountsBar({
    super.key,
    required this.leftCount,
    required this.rightCount,
    required this.leftLabel,
    required this.rightLabel,
  });

  Widget _side(String label, int count, {required bool right}) {
    final value = (count / 22).clamp(0.0, 1.0);
    final accent = right ? GameUi.cyan : const Color(0xFF60A5FA);
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w600)),
              const SizedBox(width: 7),
              Text('$count',
                  style: TextStyle(color: accent, fontSize: 17, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 4,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: GameUi.surface.withOpacity(0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GameUi.hairline),
      ),
      child: Row(
        children: [
          _side(leftLabel, leftCount, right: false),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Icon(Icons.compare_arrows_rounded, color: Colors.white38, size: 18),
          ),
          _side(rightLabel, rightCount, right: true),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Oyuncu bilgisini (avatar + isim) kartların ÜSTÜNDE, geniş ve belirgin
/// bir başlık olarak gösterir. Kalan kart sayısı artık burada DEĞİL —
/// ekranın en üstünde iki tarafın sayısını YAN YANA gösteren
/// [StockCountsBar] içinde.
class PlayerHeader extends StatelessWidget {
  final Widget avatar;
  final String name;
  final int stockCount;
  /// Varsayılan false: sayı rozeti burada çizilmez (StockCountsBar'da
  /// gösteriliyor). İhtiyaç olursa true yapılabilir.
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        avatar,
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (showCount) ...[
          const SizedBox(width: 10),
          StockCountBadge(count: stockCount),
        ],
      ],
    );
  }
}

/// Tek bir kart-sayısı rozeti (ikon + kalın rakam).
class StockCountBadge extends StatelessWidget {
  final int count;
  final Color numberColor;

  const StockCountBadge(
      {super.key, required this.count, this.numberColor = Colors.amber});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.style, color: Colors.white70, size: 16),
          const SizedBox(width: 5),
          Text(
            '$count',
            style: TextStyle(
              color: numberColor,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ekranın en üstünde, iki tarafın kalan kart sayısını YAN YANA gösteren
/// çubuk.
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(leftLabel,
                  style: const TextStyle(color: Colors.white60, fontSize: 11)),
              const SizedBox(height: 2),
              StockCountBadge(count: leftCount, numberColor: Colors.white),
            ],
          ),
          const Icon(Icons.compare_arrows, color: Colors.white38, size: 20),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(rightLabel,
                  style: const TextStyle(color: Colors.white60, fontSize: 11)),
              const SizedBox(height: 2),
              StockCountBadge(count: rightCount),
            ],
          ),
        ],
      ),
    );
  }
}

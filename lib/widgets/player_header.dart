import 'package:flutter/material.dart';

/// Oyuncu bilgisini (avatar + isim + kalan kart sayısı) kartların
/// ÜSTÜNDE, geniş ve belirgin bir başlık olarak gösterir. Önceki
/// tasarımda bu bilgi kartların YANINDA (solda) dar bir sütunda
/// duruyordu; bu hem alanı sıkıştırıyordu hem de küçük görünüyordu.
class PlayerHeader extends StatelessWidget {
  final Widget avatar;
  final String name;
  final int stockCount;

  const PlayerHeader({
    super.key,
    required this.avatar,
    required this.name,
    required this.stockCount,
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
        const SizedBox(width: 10),
        Container(
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
                '$stockCount',
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

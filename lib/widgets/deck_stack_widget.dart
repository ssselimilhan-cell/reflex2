import 'package:flutter/material.dart';
import '../settings/app_settings.dart';

/// Kapalı destenin (26 kağıda kadar) kart kart gösterilmesi yerine,
/// kalınlığını sembolize eden küçük bir yığın + sayı gösterir.
class DeckStackWidget extends StatelessWidget {
  final int count;
  final String label;
  final double scale;

  const DeckStackWidget({
    super.key,
    required this.count,
    required this.label,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final layers = count <= 0 ? 0 : (count > 4 ? 4 : count);
    final unit = 26 * scale;
    final backColor = AppSettings.instance.cardBackColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: unit + 6 * scale,
          height: unit + (layers > 1 ? (layers - 1) * 2.5 * scale : 0),
          child: Stack(
            children: [
              for (var i = 0; i < layers; i++)
                Positioned(
                  top: i * 2.5 * scale,
                  left: i * 1.2 * scale,
                  child: Container(
                    width: unit,
                    height: unit,
                    decoration: BoxDecoration(
                      color: backColor,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: i == layers - 1
                        ? Center(
                            child: Icon(Icons.style,
                                color: Colors.white54, size: 14 * scale),
                          )
                        : null,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text('$label: $count',
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

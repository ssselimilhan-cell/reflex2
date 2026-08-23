import 'package:flutter/material.dart';

/// Kapalı destenin (26 kağıda kadar) kart kart gösterilmesi yerine,
/// kalınlığını sembolize eden küçük bir yığın + sayı gösterir.
class DeckStackWidget extends StatelessWidget {
  final int count;
  final String label;

  const DeckStackWidget({super.key, required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    final layers = count <= 0 ? 0 : (count > 4 ? 4 : count);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 32,
          height: 30 + (layers > 1 ? (layers - 1) * 2.5 : 0),
          child: Stack(
            children: [
              for (var i = 0; i < layers; i++)
                Positioned(
                  top: i * 2.5,
                  left: i * 1.2,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E4D8C),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: i == layers - 1
                        ? const Center(
                            child: Icon(Icons.style,
                                color: Colors.white54, size: 14),
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

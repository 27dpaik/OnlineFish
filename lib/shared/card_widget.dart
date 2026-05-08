import 'package:flutter/material.dart';

import 'card_model.dart';

class CardWidget extends StatelessWidget {
  const CardWidget({
    super.key,
    required this.card,
    this.faceUp = true,
    this.size = 56,
    this.selected = false,
    this.onTap,
  });

  final PlayingCard card;
  final bool faceUp;
  final double size;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isJoker = card.suit == Suit.joker;
    final color = card.suit.isRed
        ? const Color(0xFFC0392B)
        : const Color(0xFF1F2937);
    final bg = faceUp ? Colors.white : const Color(0xFF1E3A8A);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: size,
        height: size * 1.45,
        margin: EdgeInsets.only(top: selected ? 0 : 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Colors.amber : Colors.black26,
            width: selected ? 2.5 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: !faceUp
            ? const SizedBox.shrink()
            : isJoker
                ? Padding(
                    padding: const EdgeInsets.all(4),
                    child: FittedBox(
                      child: Text(
                        card.rank == Rank.jokerBig ? 'BIG\nJOKER' : 'SMALL\nJOKER',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: card.rank == Rank.jokerBig
                              ? const Color(0xFFC0392B)
                              : const Color(0xFF1F2937),
                          fontWeight: FontWeight.w700,
                          fontSize: size * 0.18,
                        ),
                      ),
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        card.rank.short,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: size * 0.36,
                          color: color,
                        ),
                      ),
                      Text(
                        card.suit.symbol,
                        style: TextStyle(
                          fontSize: size * 0.42,
                          color: color,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

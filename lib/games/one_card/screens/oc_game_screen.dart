import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/card_model.dart';
import '../../../shared/card_widget.dart';
import '../controller.dart';
import '../models.dart';

class OcGameScreen extends StatelessWidget {
  const OcGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OcController>(
      builder: (context, ctrl, _) {
        final s = ctrl.state;
        if (s == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (s.phase == OcPhase.finished) {
          return _Finished(state: s);
        }
        return Scaffold(
          backgroundColor: const Color(0xFF1F2937),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1F2937),
            foregroundColor: Colors.white,
            title: Text('One Card — ${s.gameId}'),
          ),
          body: SafeArea(
            child: Column(
              children: [
                if (ctrl.isLocalMode) _PlayerSwitcher(controller: ctrl, state: s),
                _OpponentRow(state: s, myId: ctrl.myActivePlayerId),
                _Table(state: s),
                Expanded(child: _LogPane(state: s)),
                _ActionBar(state: s, controller: ctrl),
                _HandPane(state: s, controller: ctrl),
                if (ctrl.lastError != null)
                  Container(
                    width: double.infinity,
                    color: Colors.amber.withValues(alpha: 0.2),
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(ctrl.lastError!,
                              style: const TextStyle(color: Colors.amber)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.amber),
                          onPressed: ctrl.clearError,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlayerSwitcher extends StatelessWidget {
  const _PlayerSwitcher({required this.controller, required this.state});
  final OcController controller;
  final OcState state;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: Text('View as:', style: TextStyle(color: Colors.white70)),
          ),
          ...state.players.map((p) {
            final selected = controller.myActivePlayerId == p.id;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: ChoiceChip(
                selected: selected,
                onSelected: (_) => controller.setViewingPlayer(p.id),
                label: Text(p.name),
                selectedColor: const Color(0xFF22C55E),
                backgroundColor: Colors.white12,
                labelStyle: TextStyle(
                    color: selected ? Colors.black : Colors.white,
                    fontSize: 12),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _OpponentRow extends StatelessWidget {
  const _OpponentRow({required this.state, required this.myId});
  final OcState state;
  final String? myId;

  @override
  Widget build(BuildContext context) {
    final opponents = state.players.where((p) => p.id != myId).toList();
    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          for (final p in opponents) ...[
            Expanded(child: _OpponentBadge(player: p, state: state)),
            const SizedBox(width: 6),
          ],
        ]..removeLast(),
      ),
    );
  }
}

class _OpponentBadge extends StatelessWidget {
  const _OpponentBadge({required this.player, required this.state});
  final OcPlayer player;
  final OcState state;

  @override
  Widget build(BuildContext context) {
    final isCurrent = state.currentPlayer.id == player.id;
    final cards = state.hands[player.id]?.length ?? 0;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isCurrent
            ? const Color(0xFF22C55E).withValues(alpha: 0.25)
            : Colors.white10,
        border: Border.all(
            color: isCurrent ? const Color(0xFF22C55E) : Colors.white24,
            width: isCurrent ? 2 : 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(player.name,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text('$cards cards',
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.state});
  final OcState state;

  @override
  Widget build(BuildContext context) {
    final declared = state.declaredSuit;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            children: [
              Container(
                width: 60,
                height: 88,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A),
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text('${state.stock.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20)),
              ),
              const SizedBox(height: 4),
              const Text('Stock',
                  style: TextStyle(color: Colors.white60, fontSize: 11)),
            ],
          ),
          Column(
            children: [
              CardWidget(card: state.topDiscard, size: 60),
              const SizedBox(height: 4),
              const Text('Discard',
                  style: TextStyle(color: Colors.white60, fontSize: 11)),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.pendingAttack > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.3),
                    border: Border.all(color: Colors.red),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Attack: ${state.pendingAttack}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              const SizedBox(height: 4),
              if (declared != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.3),
                    border: Border.all(color: Colors.amber),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                      'Suit: ${Suit.values.byName(declared).symbol}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              const SizedBox(height: 4),
              Text('Turn: ${state.currentPlayer.name}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
              Text('Direction: ${state.direction == 1 ? '→' : '←'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogPane extends StatelessWidget {
  const _LogPane({required this.state});
  final OcState state;

  @override
  Widget build(BuildContext context) {
    final entries = state.log.reversed.take(15).toList();
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        reverse: true,
        itemCount: entries.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(entries[i].text,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.state, required this.controller});
  final OcState state;
  final OcController controller;

  @override
  Widget build(BuildContext context) {
    final myId = controller.myActivePlayerId;
    final myTurn = myId != null && state.currentPlayer.id == myId;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              myTurn
                  ? "Your turn — tap a card to play, or draw"
                  : "Waiting for ${state.currentPlayer.name}…",
              style: TextStyle(
                  color: myTurn ? const Color(0xFF22C55E) : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ),
          ElevatedButton.icon(
            onPressed: myTurn
                ? () => controller.draw(playerId: myId)
                : null,
            icon: const Icon(Icons.add),
            label: Text(state.pendingAttack > 0
                ? 'Take ${state.pendingAttack}'
                : 'Draw'),
            style: ElevatedButton.styleFrom(
              backgroundColor: state.pendingAttack > 0
                  ? Colors.red
                  : const Color(0xFF22C55E),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _HandPane extends StatelessWidget {
  const _HandPane({required this.state, required this.controller});
  final OcState state;
  final OcController controller;

  @override
  Widget build(BuildContext context) {
    final myId = controller.myActivePlayerId;
    if (myId == null) return const SizedBox.shrink();
    final hand = state.handFor(myId);
    final myTurn = state.currentPlayer.id == myId;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        border: Border(top: BorderSide(color: Colors.white24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              'Your hand (${state.players.firstWhere((p) => p.id == myId).name}, '
              '${hand.length} cards)',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: hand.length,
              separatorBuilder: (_, _) => const SizedBox(width: 4),
              itemBuilder: (_, i) {
                final c = hand[i];
                return CardWidget(
                  card: c,
                  size: 56,
                  onTap: myTurn
                      ? () => _onPlayCard(context, controller, state, myId, c)
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _onPlayCard(
  BuildContext context,
  OcController controller,
  OcState state,
  String playerId,
  PlayingCard card,
) async {
  // Special case: 7 → ask which suit to declare.
  if (card.rank == Rank.seven) {
    Suit? chosen;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text('Change to which suit?',
            style: TextStyle(color: Colors.white)),
        content: Wrap(
          spacing: 8,
          children: [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs]
              .map((s) => ElevatedButton(
                    onPressed: () {
                      chosen = s;
                      Navigator.pop(ctx);
                    },
                    child: Text(s.symbol,
                        style: const TextStyle(fontSize: 24)),
                  ))
              .toList(),
        ),
      ),
    );
    if (chosen != null) {
      await controller.play(
        playerId: playerId,
        card: card,
        declaredSuitForSeven: chosen,
      );
    }
    return;
  }
  await controller.play(playerId: playerId, card: card);
}

class _Finished extends StatelessWidget {
  const _Finished({required this.state});
  final OcState state;

  @override
  Widget build(BuildContext context) {
    final winner = state.players.firstWhere((p) => p.id == state.winnerId,
        orElse: () => const OcPlayer(id: '', name: '?'));
    return Scaffold(
      backgroundColor: const Color(0xFF1F2937),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, color: Colors.amber, size: 80),
            const SizedBox(height: 16),
            Text('${winner.name} wins!',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('Back to home'),
            ),
          ],
        ),
      ),
    );
  }
}

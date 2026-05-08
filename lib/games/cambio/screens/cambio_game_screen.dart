import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/card_model.dart';
import '../../../shared/card_widget.dart';
import '../controller.dart';
import '../models.dart';

class CambioGameScreen extends StatefulWidget {
  const CambioGameScreen({super.key});

  @override
  State<CambioGameScreen> createState() => _CambioGameScreenState();
}

class _CambioGameScreenState extends State<CambioGameScreen> {
  bool _stickMode = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<CambioController>(
      builder: (context, ctrl, _) {
        final s = ctrl.state;
        if (s == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (s.phase == CambioPhase.finished) return _Finished(state: s);
        final myId = ctrl.myActivePlayerId!;
        return Scaffold(
          backgroundColor: const Color(0xFF2D1B69),
          appBar: AppBar(
            backgroundColor: const Color(0xFF2D1B69),
            foregroundColor: Colors.white,
            title: Text('Cambio — ${s.gameId}'),
            actions: [
              IconButton(
                icon: Icon(_stickMode ? Icons.front_hand : Icons.front_hand_outlined,
                    color: _stickMode ? Colors.amber : Colors.white),
                tooltip: 'Toggle stick mode',
                onPressed: () => setState(() => _stickMode = !_stickMode),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                if (ctrl.isLocalMode) _PlayerSwitcher(controller: ctrl, state: s),
                _Status(state: s, myId: myId, stickMode: _stickMode),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        _OpponentsRow(
                          state: s,
                          myId: myId,
                          stickMode: _stickMode,
                          onCardTap: (target, pos) =>
                              _onOpponentCardTap(context, ctrl, s, myId, target, pos),
                        ),
                        const SizedBox(height: 12),
                        _Table(state: s, myId: myId),
                        const SizedBox(height: 12),
                        _MyHand(
                          state: s,
                          myId: myId,
                          stickMode: _stickMode,
                          onCardTap: (pos) =>
                              _onMyCardTap(context, ctrl, s, myId, pos),
                        ),
                      ],
                    ),
                  ),
                ),
                _ActionBar(state: s, controller: ctrl, myId: myId),
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

  void _onMyCardTap(BuildContext ctx, CambioController c, CambioState s,
      String myId, int pos) {
    if (_stickMode) {
      c.stick(stickerId: myId, ownerPlayerId: myId, position: pos);
      return;
    }
    if (s.phase == CambioPhase.initialPeek &&
        !s.initialPeekDone.contains(myId)) {
      // Initial peek shows bottom 2 anyway; tapping doesn't do anything here.
      return;
    }
    if (s.drawn?.playerId == myId) {
      c.swapDrawn(playerId: myId, position: pos);
      return;
    }
    final p = s.pending;
    if (p == null || p.activePlayerId != myId) return;
    switch (p.type) {
      case PendingPowerType.peekOwn:
        c.peekOwn(playerId: myId, position: pos);
        break;
      case PendingPowerType.blindSwitchPickMine:
        c.blindSwitchMine(playerId: myId, myPosition: pos);
        break;
      case PendingPowerType.kingSwitchPickMine:
        c.kingSwitchMine(playerId: myId, myPosition: pos);
        break;
      default:
        break;
    }
  }

  void _onOpponentCardTap(BuildContext ctx, CambioController c, CambioState s,
      String myId, String targetId, int pos) {
    if (_stickMode) {
      c.stick(stickerId: myId, ownerPlayerId: targetId, position: pos);
      return;
    }
    final p = s.pending;
    if (p == null || p.activePlayerId != myId) return;
    switch (p.type) {
      case PendingPowerType.peekOther:
        c.peekOther(
            playerId: myId, targetPlayerId: targetId, position: pos);
        break;
      case PendingPowerType.blindSwitchPickOther:
        c.blindSwitchOther(
          playerId: myId,
          otherPlayerId: targetId,
          otherPosition: pos,
        );
        break;
      case PendingPowerType.kingLook:
        c.kingLook(
            playerId: myId, targetPlayerId: targetId, position: pos);
        break;
      case PendingPowerType.kingSwitchPickOther:
        c.kingSwitchOther(
          playerId: myId,
          otherPlayerId: targetId,
          otherPosition: pos,
        );
        break;
      default:
        break;
    }
  }
}

class _PlayerSwitcher extends StatelessWidget {
  const _PlayerSwitcher({required this.controller, required this.state});
  final CambioController controller;
  final CambioState state;

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
                selectedColor: const Color(0xFFA855F7),
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

class _Status extends StatelessWidget {
  const _Status({
    required this.state,
    required this.myId,
    required this.stickMode,
  });
  final CambioState state;
  final String myId;
  final bool stickMode;

  @override
  Widget build(BuildContext context) {
    String text;
    Color color = Colors.white70;
    final p = state.pending;
    final myTurn = state.currentPlayer.id == myId;
    if (stickMode) {
      text = 'STICK MODE — tap any card matching the discard top';
      color = Colors.amber;
    } else if (state.phase == CambioPhase.initialPeek) {
      if (!state.initialPeekDone.contains(myId)) {
        text = 'Initial peek — memorize your bottom 2 cards, then tap "Done"';
        color = const Color(0xFFFCD34D);
      } else {
        final waiting = state.players
            .where((pl) => !state.initialPeekDone.contains(pl.id))
            .map((pl) => pl.name)
            .join(', ');
        text = 'Waiting for: $waiting';
      }
    } else if (state.phase == CambioPhase.finalRound) {
      final caller = state.players
          .firstWhere((pl) => pl.id == state.cambioCallerId)
          .name;
      text =
          'CAMBIO called by $caller — ${state.finalRoundRemaining} turns left';
      color = Colors.amber;
    } else if (p != null && p.activePlayerId == myId) {
      text = switch (p.type) {
        PendingPowerType.peekOwn =>
          'Peek own: tap one of your cards (acknowledge when done)',
        PendingPowerType.peekOther =>
          'Peek other: tap an opponent\'s card',
        PendingPowerType.blindSwitchPickMine =>
          'Blind switch: tap one of your cards (no peek)',
        PendingPowerType.blindSwitchPickOther =>
          'Blind switch: now tap an opponent\'s card',
        PendingPowerType.kingLook =>
          'Black King: tap any card to look at it',
        PendingPowerType.kingSwitchPickMine =>
          'Black King: now tap one of your cards to give away',
        PendingPowerType.kingSwitchPickOther =>
          'Black King: tap an opponent\'s card to receive',
      };
      color = const Color(0xFFFCD34D);
    } else if (p != null) {
      final actorName =
          state.players.firstWhere((pl) => pl.id == p.activePlayerId).name;
      text = '$actorName is using a power…';
    } else if (state.drawn?.playerId == myId) {
      text = 'You drew a card — tap a slot to swap, or "Discard"';
      color = const Color(0xFF22C55E);
    } else if (state.drawn != null) {
      final actorName =
          state.players.firstWhere((pl) => pl.id == state.drawn!.playerId).name;
      text = '$actorName is choosing what to do with their draw…';
    } else if (myTurn) {
      text = 'Your turn — Draw, Cambio, or stick a card';
      color = const Color(0xFF22C55E);
    } else {
      text = '${state.currentPlayer.name}\'s turn';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.black26,
      child: Text(text,
          style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.state, required this.myId});
  final CambioState state;
  final String myId;

  @override
  Widget build(BuildContext context) {
    final showDrawnFaceUp = state.drawn?.playerId == myId;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1147),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            children: [
              Container(
                width: 50,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A),
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text('${state.stock.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 4),
              const Text('Stock',
                  style: TextStyle(color: Colors.white60, fontSize: 11)),
            ],
          ),
          Column(
            children: [
              if (state.topDiscard != null)
                CardWidget(card: state.topDiscard!, size: 50)
              else
                const SizedBox(width: 50, height: 72),
              const SizedBox(height: 4),
              const Text('Discard',
                  style: TextStyle(color: Colors.white60, fontSize: 11)),
            ],
          ),
          Column(
            children: [
              if (state.drawn != null)
                showDrawnFaceUp
                    ? CardWidget(
                        card: PlayingCard.fromId(state.drawn!.cardId),
                        size: 50)
                    : Container(
                        width: 50,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A8A),
                          border: Border.all(color: Colors.amber, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      )
              else
                const SizedBox(width: 50, height: 72),
              const SizedBox(height: 4),
              const Text('Drawn',
                  style: TextStyle(color: Colors.white60, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _OpponentsRow extends StatelessWidget {
  const _OpponentsRow({
    required this.state,
    required this.myId,
    required this.stickMode,
    required this.onCardTap,
  });
  final CambioState state;
  final String myId;
  final bool stickMode;
  final void Function(String targetId, int position) onCardTap;

  @override
  Widget build(BuildContext context) {
    final opponents =
        state.players.where((p) => p.id != myId).toList();
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: opponents
          .map((p) => _PlayerHand(
                state: state,
                player: p,
                myId: myId,
                stickMode: stickMode,
                onCardTap: (pos) => onCardTap(p.id, pos),
              ))
          .toList(),
    );
  }
}

class _MyHand extends StatelessWidget {
  const _MyHand({
    required this.state,
    required this.myId,
    required this.stickMode,
    required this.onCardTap,
  });
  final CambioState state;
  final String myId;
  final bool stickMode;
  final void Function(int position) onCardTap;

  @override
  Widget build(BuildContext context) {
    final me = state.players.firstWhere((p) => p.id == myId);
    return _PlayerHand(
      state: state,
      player: me,
      myId: myId,
      stickMode: stickMode,
      onCardTap: onCardTap,
    );
  }
}

class _PlayerHand extends StatelessWidget {
  const _PlayerHand({
    required this.state,
    required this.player,
    required this.myId,
    required this.stickMode,
    required this.onCardTap,
  });
  final CambioState state;
  final CambioPlayer player;
  final String myId;
  final bool stickMode;
  final void Function(int position) onCardTap;

  @override
  Widget build(BuildContext context) {
    final hand = state.hands[player.id] ?? const [];
    final isMe = player.id == myId;
    final isCurrent = state.currentPlayer.id == player.id;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCurrent
              ? const Color(0xFF22C55E)
              : (isMe ? Colors.amber : Colors.white24),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(player.name,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Column(
            children: [
              for (var row = 0; row < 2; row++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var col = 0; col < 2; col++)
                      Padding(
                        padding: const EdgeInsets.all(3),
                        child: _Slot(
                          state: state,
                          player: player,
                          myId: myId,
                          position: row * 2 + col,
                          stickMode: stickMode,
                          hand: hand,
                          onTap: () => onCardTap(row * 2 + col),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.state,
    required this.player,
    required this.myId,
    required this.position,
    required this.stickMode,
    required this.hand,
    required this.onTap,
  });
  final CambioState state;
  final CambioPlayer player;
  final String myId;
  final int position;
  final bool stickMode;
  final List<String> hand;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (position >= hand.length) {
      return const SizedBox(width: 40, height: 58);
    }
    final cardId = hand[position];
    final card = PlayingCard.fromId(cardId);
    final isMe = player.id == myId;
    final isInitialPeekVisible = state.phase == CambioPhase.initialPeek &&
        isMe &&
        position >= 2 &&
        !state.initialPeekDone.contains(myId);
    final privatelyVisible = state.privateReveals.any(
      (r) =>
          r.viewerId == myId &&
          r.ofPlayerId == player.id &&
          r.position == position,
    );
    final faceUp = isInitialPeekVisible || privatelyVisible;
    return GestureDetector(
      onTap: onTap,
      child: CardWidget(
        card: card,
        faceUp: faceUp,
        size: 40,
        selected: stickMode,
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.state,
    required this.controller,
    required this.myId,
  });
  final CambioState state;
  final CambioController controller;
  final String myId;

  @override
  Widget build(BuildContext context) {
    final myTurn = state.currentPlayer.id == myId;
    final p = state.pending;
    final hasPeek = state.privateReveals.any((r) => r.viewerId == myId);

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: [
          if (state.phase == CambioPhase.initialPeek &&
              !state.initialPeekDone.contains(myId))
            ElevatedButton(
              onPressed: () => controller.finishInitialPeek(myId),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
              ),
              child: const Text('Done peeking'),
            ),
          if ((state.phase == CambioPhase.playing ||
                  state.phase == CambioPhase.finalRound) &&
              myTurn &&
              state.drawn == null &&
              p == null) ...[
            ElevatedButton.icon(
              onPressed: () => controller.drawFromStock(myId),
              icon: const Icon(Icons.add),
              label: const Text('Draw'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA855F7),
                foregroundColor: Colors.white,
              ),
            ),
            if (state.phase == CambioPhase.playing)
              OutlinedButton.icon(
                onPressed: () => controller.callCambio(myId),
                icon: const Icon(Icons.flag),
                label: const Text('Cambio!'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amber,
                  side: const BorderSide(color: Colors.amber),
                ),
              ),
          ],
          if (state.drawn?.playerId == myId)
            ElevatedButton.icon(
              onPressed: () => controller.discardDrawn(playerId: myId),
              icon: const Icon(Icons.delete),
              label: const Text('Discard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          if (hasPeek && p?.activePlayerId == myId)
            ElevatedButton.icon(
              onPressed: () => controller.acknowledgePeek(myId),
              icon: const Icon(Icons.visibility_off),
              label: const Text('I memorized it'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

class _Finished extends StatelessWidget {
  const _Finished({required this.state});
  final CambioState state;

  @override
  Widget build(BuildContext context) {
    final scores = state.finalScores ?? const {};
    final sorted = state.players.toList()
      ..sort((a, b) =>
          (scores[a.id] ?? 0).compareTo(scores[b.id] ?? 0));
    final winner = state.players.firstWhere((p) => p.id == state.winnerId,
        orElse: () => const CambioPlayer(id: '', name: '?'));
    return Scaffold(
      backgroundColor: const Color(0xFF2D1B69),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D1B69),
        foregroundColor: Colors.white,
        title: const Text('Cambio — Final scores'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 24),
              for (final p in sorted)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(p.name,
                            style: const TextStyle(color: Colors.white)),
                      ),
                      if (p.id == state.cambioCallerId)
                        const Text('CAMBIO',
                            style: TextStyle(color: Colors.amber, fontSize: 11)),
                      const SizedBox(width: 8),
                      Text('${scores[p.id]} pts',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('Back to home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

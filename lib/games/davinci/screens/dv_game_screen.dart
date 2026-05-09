import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controller.dart';
import '../models.dart';

class DvGameScreen extends StatelessWidget {
  const DvGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DvController>(
      builder: (context, ctrl, _) {
        final s = ctrl.state;
        if (s == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (s.phase == DvPhase.finished) return _Finished(state: s);
        final myId = ctrl.myActivePlayerId!;
        return Scaffold(
          backgroundColor: const Color(0xFF1A1A2E),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1A1A2E),
            foregroundColor: Colors.white,
            title: Text('Da Vinci Code — ${s.gameId}'),
          ),
          body: SafeArea(
            child: Column(
              children: [
                if (ctrl.isLocalMode)
                  _PlayerSwitcher(state: s, controller: ctrl),
                _Status(state: s, myId: myId),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        _Stock(state: s, myId: myId),
                        const SizedBox(height: 12),
                        for (final p in s.players)
                          if (p.id != myId)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: _OpponentRow(
                                  state: s,
                                  player: p,
                                  myId: myId,
                                  controller: ctrl),
                            ),
                        const SizedBox(height: 16),
                        _MyHand(state: s, myId: myId, controller: ctrl),
                      ],
                    ),
                  ),
                ),
                _ActionBar(state: s, myId: myId, controller: ctrl),
                if (ctrl.lastError != null)
                  Container(
                    width: double.infinity,
                    color: Colors.amber.withValues(alpha: 0.2),
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Expanded(
                            child: Text(ctrl.lastError!,
                                style: const TextStyle(color: Colors.amber))),
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
  const _PlayerSwitcher({required this.state, required this.controller});
  final DvState state;
  final DvController controller;

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
                selectedColor: const Color(0xFFFCD34D),
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
  const _Status({required this.state, required this.myId});
  final DvState state;
  final String myId;

  @override
  Widget build(BuildContext context) {
    final myTurn = state.currentPlayer.id == myId;
    String text;
    if (state.awaitingChoiceAfterCorrect && myTurn) {
      text = 'Right! Guess again, or stop.';
    } else if (state.drawn?.playerId == myId) {
      text = state.drawn!.block.isJoker
          ? 'Joker drawn — pick where to insert it'
          : 'Pick an opponent block to guess.';
    } else if (myTurn) {
      text = 'Your turn — draw a block.';
    } else {
      text = "${state.currentPlayer.name}'s turn.";
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.black26,
      child: Text(text,
          style: TextStyle(
              color: myTurn ? const Color(0xFFFCD34D) : Colors.white70,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _Stock extends StatelessWidget {
  const _Stock({required this.state, required this.myId});
  final DvState state;
  final String myId;

  @override
  Widget build(BuildContext context) {
    final showDrawn = state.drawn?.playerId == myId;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            children: [
              Container(
                width: 50,
                height: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
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
              if (state.drawn != null)
                showDrawn
                    ? _BlockTile(block: state.drawn!.block, faceUp: true)
                    : _BlockTile(block: state.drawn!.block, faceUp: false)
              else
                const SizedBox(width: 50, height: 70),
              const SizedBox(height: 4),
              Text(
                  state.drawn == null
                      ? 'Drawn'
                      : (showDrawn ? 'You drew' : '${state.players.firstWhere((p) => p.id == state.drawn!.playerId).name} drew'),
                  style:
                      const TextStyle(color: Colors.white60, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _OpponentRow extends StatelessWidget {
  const _OpponentRow({
    required this.state,
    required this.player,
    required this.myId,
    required this.controller,
  });
  final DvState state;
  final DvPlayer player;
  final String myId;
  final DvController controller;

  @override
  Widget build(BuildContext context) {
    final hand = state.hands[player.id] ?? const [];
    final isCurrent = state.currentPlayer.id == player.id;
    final canGuess = state.currentPlayer.id == myId &&
        (state.drawn != null || state.awaitingChoiceAfterCorrect);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isCurrent ? const Color(0xFFFCD34D) : Colors.white24,
            width: isCurrent ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(player.name,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: List.generate(hand.length, (i) {
              final block = hand[i];
              return GestureDetector(
                onTap: (block.revealed || !canGuess)
                    ? null
                    : () => _showGuessDialog(
                          context,
                          state,
                          controller,
                          targetId: player.id,
                          position: i,
                          block: block,
                        ),
                child: _BlockTile(
                  block: block,
                  faceUp: block.revealed,
                  selectable: canGuess && !block.revealed,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _MyHand extends StatelessWidget {
  const _MyHand({
    required this.state,
    required this.myId,
    required this.controller,
  });
  final DvState state;
  final String myId;
  final DvController controller;

  @override
  Widget build(BuildContext context) {
    final hand = state.hands[myId] ?? const [];
    final me = state.players.firstWhere((p) => p.id == myId);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your hand (${me.name})',
              style: const TextStyle(color: Colors.amber, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: hand
                .map((b) => _BlockTile(block: b, faceUp: true))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.state,
    required this.myId,
    required this.controller,
  });
  final DvState state;
  final String myId;
  final DvController controller;

  @override
  Widget build(BuildContext context) {
    final myTurn = state.currentPlayer.id == myId;
    final canDraw =
        myTurn && state.drawn == null && !state.awaitingChoiceAfterCorrect;
    final hasDrawnNonJoker =
        state.drawn?.playerId == myId && !state.drawn!.block.isJoker;
    final hasDrawnJoker =
        state.drawn?.playerId == myId && state.drawn!.block.isJoker;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: canDraw ? () => controller.drawFromStock(myId) : null,
            icon: const Icon(Icons.add),
            label: const Text('Draw'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFCD34D),
              foregroundColor: Colors.black,
            ),
          ),
          if (hasDrawnNonJoker)
            ElevatedButton(
              onPressed: () => controller.placeDrawn(myId),
              child: const Text('Place (auto-sort)'),
            ),
          if (hasDrawnJoker)
            ElevatedButton(
              onPressed: () =>
                  _showJokerPositionDialog(context, state, controller, myId),
              child: const Text('Place joker…'),
            ),
          if (state.awaitingChoiceAfterCorrect &&
              state.currentPlayer.id == myId)
            ElevatedButton.icon(
              onPressed: () => controller.stopAfterCorrect(myId),
              icon: const Icon(Icons.stop),
              label: const Text('Stop'),
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

Future<void> _showGuessDialog(
  BuildContext context,
  DvState state,
  DvController controller, {
  required String targetId,
  required int position,
  required DvBlock block,
}) async {
  int? guess;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
            'Guess ${state.players.firstWhere((p) => p.id == targetId).name}\'s slot ${position + 1}',
            style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var v = 0; v <= 11; v++)
                    ChoiceChip(
                      label: Text('$v'),
                      selected: guess == v,
                      onSelected: (_) => setState(() => guess = v),
                    ),
                  ChoiceChip(
                    label: const Text('Joker'),
                    selected: guess == -1,
                    onSelected: (_) => setState(() => guess = -1),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: guess == null
                ? null
                : () async {
                    Navigator.pop(ctx);
                    await controller.guess(
                      guesserId: state.currentPlayer.id,
                      targetId: targetId,
                      position: position,
                      value: guess == -1 ? null : guess,
                    );
                  },
            child: const Text('Guess'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showJokerPositionDialog(
  BuildContext context,
  DvState state,
  DvController controller,
  String myId,
) async {
  final hand = state.hands[myId] ?? const [];
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      title: const Text('Insert joker at…',
          style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i <= hand.length; i++)
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await controller.placeDrawnAt(myId, i);
                },
                child: Text(i == 0
                    ? 'leftmost'
                    : (i == hand.length ? 'rightmost' : 'after slot $i')),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel')),
      ],
    ),
  );
}

class _BlockTile extends StatelessWidget {
  const _BlockTile({
    required this.block,
    required this.faceUp,
    this.selectable = false,
  });
  final DvBlock block;
  final bool faceUp;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final isBlack = block.color == DvColor.black;
    final bg = isBlack ? const Color(0xFF1F2937) : Colors.white;
    final fg = isBlack ? Colors.white : Colors.black;
    final border = selectable ? Colors.amber : Colors.white24;
    return Container(
      width: 36,
      height: 52,
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: selectable ? 2 : 1),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: faceUp
          ? Text(
              block.isJoker ? '★' : '${block.value}',
              style: TextStyle(
                color: fg,
                fontSize: block.isJoker ? 20 : 16,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }
}

class _Finished extends StatelessWidget {
  const _Finished({required this.state});
  final DvState state;

  @override
  Widget build(BuildContext context) {
    final winner = state.players.firstWhere(
      (p) => p.id == state.winnerId,
      orElse: () => const DvPlayer(id: '', name: '?'),
    );
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
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

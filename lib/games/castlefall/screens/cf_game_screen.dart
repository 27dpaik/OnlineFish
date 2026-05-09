import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controller.dart';
import '../models.dart';
import '../word_bank.dart';

class CfGameScreen extends StatelessWidget {
  const CfGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CfController>(
      builder: (context, ctrl, _) {
        final s = ctrl.state;
        if (s == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (s.phase == CfPhase.lobby) {
          // host pressed "back to lobby" or similar; pop out
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          backgroundColor: const Color(0xFF1F2A44),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1F2A44),
            foregroundColor: Colors.white,
            title: Text('Castlefall — ${s.gameId}'),
          ),
          body: SafeArea(
            child: ctrl.isLocalMode
                ? _LocalView(state: s, controller: ctrl)
                : _OnlineView(state: s, controller: ctrl),
          ),
        );
      },
    );
  }
}

/// In local hot-seat mode each player taps their name to view their own
/// word in private, then hands off the device. We hide the wordlist behind
/// a "tap to reveal" gate.
class _LocalView extends StatefulWidget {
  const _LocalView({required this.state, required this.controller});
  final CfState state;
  final CfController controller;

  @override
  State<_LocalView> createState() => _LocalViewState();
}

class _LocalViewState extends State<_LocalView> {
  String? _selectedId;
  bool _revealed = false;
  final Set<String> _seen = {};

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    if (s.phase == CfPhase.revealed) {
      return _RevealView(state: s, controller: widget.controller);
    }
    if (_selectedId == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Tap your name to see your word. Hand the device to one player at a time.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          for (final p in s.players)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ElevatedButton(
                onPressed: () => setState(() {
                  _selectedId = p.id;
                  _revealed = false;
                }),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: _seen.contains(p.id)
                      ? Colors.white12
                      : const Color(0xFF60A5FA),
                  foregroundColor: Colors.white,
                ),
                child:
                    Text(p.name, style: const TextStyle(fontSize: 18)),
              ),
            ),
          const SizedBox(height: 24),
          if (_seen.length == s.players.length)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Everyone has seen their word — talk it out, then declare or guess.',
                style: TextStyle(color: Colors.amber),
              ),
            ),
          const SizedBox(height: 12),
          if (s.declaration != null)
            _DeclarationStrip(state: s, controller: widget.controller),
          const SizedBox(height: 12),
          _ActionButtons(
              state: s,
              myId: _selectedId,
              controller: widget.controller),
        ],
      );
    }
    final me = s.players.firstWhere((p) => p.id == _selectedId);
    if (!_revealed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(me.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => setState(() {
                  _revealed = true;
                  _seen.add(me.id);
                }),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 16),
                  backgroundColor: const Color(0xFF60A5FA),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Reveal my word', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() => _selectedId = null),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      );
    }
    return _WordView(
      state: s,
      myId: me.id,
      onDone: () => setState(() => _selectedId = null),
    );
  }
}

class _OnlineView extends StatelessWidget {
  const _OnlineView({required this.state, required this.controller});
  final CfState state;
  final CfController controller;

  @override
  Widget build(BuildContext context) {
    if (state.phase == CfPhase.revealed) {
      return _RevealView(state: state, controller: controller);
    }
    final myId = controller.myPlayerId;
    final isMe = state.players.any((p) => p.id == myId);
    if (!isMe) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            "You're not in this round — wait for the next one.",
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    return Column(
      children: [
        if (state.declaration != null)
          _DeclarationStrip(state: state, controller: controller),
        Expanded(
            child:
                _WordView(state: state, myId: myId, onDone: null)),
        _ActionButtons(state: state, myId: myId, controller: controller),
      ],
    );
  }
}

/// Shows the player's word + the shuffled list of 16. The list order is
/// derived deterministically from the player's id, so each device shows a
/// different but stable order.
class _WordView extends StatelessWidget {
  const _WordView({
    required this.state,
    required this.myId,
    required this.onDone,
  });
  final CfState state;
  final String myId;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final round = state.round;
    if (round == null) return const SizedBox.shrink();
    final myWord = round.wordFor(myId);
    final mePlayer = state.players.firstWhere((p) => p.id == myId);
    final shuffled = [...round.wordList]
      ..shuffle(Random(myId.hashCode + state.seed));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(mePlayer.name,
            style: const TextStyle(color: Colors.white60, fontSize: 14)),
        const SizedBox(height: 4),
        const Text('Your word',
            style: TextStyle(color: Colors.white60, fontSize: 14)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF60A5FA),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            myWord,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        Text('Round wordlist (${round.categoryName})',
            style: const TextStyle(color: Colors.white60, fontSize: 14)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: shuffled.map((w) {
            final isMine = w == myWord;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color:
                    isMine ? const Color(0xFF60A5FA) : Colors.white10,
                border: Border.all(
                    color: isMine ? Colors.white : Colors.white24,
                    width: isMine ? 2 : 1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(w,
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: isMine ? FontWeight.bold : FontWeight.normal)),
            );
          }).toList(),
        ),
        if (onDone != null) ...[
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onDone,
            style: ElevatedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              backgroundColor: Colors.white24,
              foregroundColor: Colors.white,
            ),
            child: const Text('Done — pass the device'),
          ),
        ],
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.state,
    required this.myId,
    required this.controller,
  });
  final CfState state;
  final String? myId;
  final CfController controller;

  @override
  Widget build(BuildContext context) {
    if (myId == null) return const SizedBox.shrink();
    final inProgress =
        state.phase == CfPhase.playing || state.phase == CfPhase.declaring;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          if (state.phase == CfPhase.playing)
            ElevatedButton.icon(
              onPressed: () => _showDeclareDialog(context, state, controller, myId!),
              icon: const Icon(Icons.flag),
              label: const Text('Declare team'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
            ),
          if (inProgress)
            ElevatedButton.icon(
              onPressed: () =>
                  _showGuessDialog(context, state, controller, myId!),
              icon: const Icon(Icons.psychology),
              label: const Text('Guess word'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

class _DeclarationStrip extends StatefulWidget {
  const _DeclarationStrip({required this.state, required this.controller});
  final CfState state;
  final CfController controller;

  @override
  State<_DeclarationStrip> createState() => _DeclarationStripState();
}

class _DeclarationStripState extends State<_DeclarationStrip> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dec = widget.state.declaration!;
    final declarer = widget.state.players
        .firstWhere((p) => p.id == dec.declarerId)
        .name;
    if (dec.kind == 'word') {
      return Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.2),
          border: Border.all(color: Colors.red),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('$declarer guessed the other team\'s word: "${dec.guessedWord}"',
            style: const TextStyle(color: Colors.white)),
      );
    }
    final deadline = dec.deadlineAt!;
    final secs = deadline.difference(DateTime.now()).inSeconds;
    final claimed = (dec.claimedPlayerIds ?? const [])
        .map((id) => widget.state.players
            .firstWhere((p) => p.id == id, orElse: () => widget.state.players.first)
            .name)
        .join(', ');
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.2),
        border: Border.all(color: Colors.amber),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              '$declarer declares: "$claimed" are all on my team',
              style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 4),
          Text(secs > 0 ? '$secs seconds left' : 'Time\'s up — tap to reveal',
              style: const TextStyle(color: Colors.amber, fontSize: 12)),
          if (secs <= 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: ElevatedButton(
                onPressed: () => widget.controller.resolveTeamDeclaration(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Reveal'),
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> _showDeclareDialog(
  BuildContext context,
  CfState state,
  CfController controller,
  String myId,
) async {
  final selected = <String>{myId};
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        backgroundColor: const Color(0xFF1F2A44),
        title: const Text('Declare team',
            style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pick the players you claim are on your team (you must include yourself).',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              ...state.players.map((p) => CheckboxListTile(
                    value: selected.contains(p.id),
                    onChanged: p.id == myId
                        ? null
                        : (v) => setState(() {
                              if (v ?? false) {
                                selected.add(p.id);
                              } else {
                                selected.remove(p.id);
                              }
                            }),
                    title: Text(p.name,
                        style: const TextStyle(color: Colors.white)),
                    subtitle: p.id == myId
                        ? const Text('(you)',
                            style: TextStyle(color: Colors.white60))
                        : null,
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await controller.declareTeam(
                declarerId: myId,
                claimedPlayerIds: selected.toList(),
              );
            },
            child: const Text('Declare'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showGuessDialog(
  BuildContext context,
  CfState state,
  CfController controller,
  String myId,
) async {
  final round = state.round;
  if (round == null) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1F2A44),
      title: const Text('Guess the other team\'s word',
          style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: round.wordList
              .map((w) => ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await controller.guessWord(
                          declarerId: myId, guessedWord: w);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(w),
                  ))
              .toList(),
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

class _RevealView extends StatefulWidget {
  const _RevealView({required this.state, required this.controller});
  final CfState state;
  final CfController controller;

  @override
  State<_RevealView> createState() => _RevealViewState();
}

class _RevealViewState extends State<_RevealView> {
  String? _category;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final round = s.round!;
    final dec = s.declaration;
    final wA = round.wordA;
    final wB = round.wordB;
    final aNames = round.teamA
        .map((id) => s.players.firstWhere((p) => p.id == id).name)
        .toList();
    final bNames = round.teamB
        .map((id) => s.players.firstWhere((p) => p.id == id).name)
        .toList();
    final isHost = widget.controller.myPlayerId == s.hostId;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Round over',
            style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (dec != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (dec.success ?? false)
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.red.withValues(alpha: 0.2),
              border: Border.all(
                  color: (dec.success ?? false) ? Colors.green : Colors.red),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              dec.kind == 'word'
                  ? '${s.players.firstWhere((p) => p.id == dec.declarerId).name} guessed "${dec.guessedWord}" → ${(dec.success ?? false) ? "RIGHT" : "WRONG"}'
                  : '${s.players.firstWhere((p) => p.id == dec.declarerId).name} declared their team → ${(dec.success ?? false) ? "RIGHT" : "WRONG"}',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        const SizedBox(height: 16),
        _teamCard('Team A', wA, aNames, const Color(0xFF60A5FA)),
        const SizedBox(height: 8),
        _teamCard('Team B', wB, bNames, const Color(0xFFF87171)),
        const SizedBox(height: 24),
        if (isHost) ...[
          const Text('Next round category:',
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: castlefallBank
                .map((c) => ChoiceChip(
                      selected: _category == c.name,
                      onSelected: (_) => setState(() => _category = c.name),
                      label: Text(c.name),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _category == null
                ? null
                : () => widget.controller.nextRound(_category!),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
              backgroundColor: const Color(0xFF60A5FA),
              foregroundColor: Colors.white,
            ),
            child: const Text('Start next round'),
          ),
        ] else
          const Text('Waiting for host to start the next round…',
              style: TextStyle(color: Colors.white70)),
      ],
    );
  }

  Widget _teamCard(
      String label, String word, List<String> names, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(word,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(names.join(', '),
              style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

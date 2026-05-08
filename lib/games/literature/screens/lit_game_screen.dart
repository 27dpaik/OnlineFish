import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/card_model.dart';
import '../../../shared/card_widget.dart';
import '../controller.dart';
import '../half_suite.dart';
import '../models.dart';
import 'lit_declare_screen.dart';

class LitGameScreen extends StatelessWidget {
  const LitGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LitController>(
      builder: (context, ctrl, _) {
        final s = ctrl.state;
        if (s == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (s.phase == LitPhase.finished) return _FinishedScreen(state: s);
        return Scaffold(
          backgroundColor: const Color(0xFF0E2A1E),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0E2A1E),
            foregroundColor: Colors.white,
            title: Text(
                '${s.gameId}  •  A ${s.teamScore(TeamId.a)}–${s.teamScore(TeamId.b)} B'),
          ),
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    _HalfSuiteStrip(state: s),
                    if (ctrl.isLocalMode)
                      _SeatSwitcher(controller: ctrl, state: s),
                    _OpponentRow(state: s, mySeatId: ctrl.mySeatId),
                    const Expanded(child: SizedBox.shrink()),
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
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(child: _AnnouncementOverlay(state: s)),
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

class _HalfSuiteStrip extends StatelessWidget {
  const _HalfSuiteStrip({required this.state});
  final LitGameState state;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemBuilder: (_, i) {
          final hs = HalfSuites.all[i];
          final winner = state.claimedHalfSuites[hs.id];
          final color = winner == null
              ? Colors.white24
              : (winner == TeamId.a
                  ? const Color(0xFF60A5FA)
                  : const Color(0xFFF87171));
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.25),
              border: Border.all(color: color),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(hs.name,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemCount: HalfSuites.all.length,
      ),
    );
  }
}

class _SeatSwitcher extends StatelessWidget {
  const _SeatSwitcher({required this.controller, required this.state});
  final LitController controller;
  final LitGameState state;

  @override
  Widget build(BuildContext context) {
    final mine = controller.mySeatId;
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
          ...state.seats.map((seat) {
            final selected = seat.id == mine;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: ChoiceChip(
                selected: selected,
                onSelected: (_) => controller.setViewingSeat(seat.id),
                label: Text(state.seatLabel(seat.id)),
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
  const _OpponentRow({required this.state, required this.mySeatId});
  final LitGameState state;
  final String? mySeatId;

  @override
  Widget build(BuildContext context) {
    if (mySeatId == null) return const SizedBox.shrink();
    final myTeam = state.seatById(mySeatId!).team;
    final oppSeats = state.seatsOnTeam(myTeam.opponent);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        children: [
          for (final seat in oppSeats) ...[
            Expanded(child: _OpponentBadge(seat: seat, state: state)),
            const SizedBox(width: 6),
          ],
        ]..removeLast(),
      ),
    );
  }
}

class _OpponentBadge extends StatelessWidget {
  const _OpponentBadge({required this.seat, required this.state});
  final LitSeat seat;
  final LitGameState state;

  @override
  Widget build(BuildContext context) {
    final isCurrent = state.currentSeatId == seat.id;
    final cardCount = state.hands[seat.id]?.length ?? 0;
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
          Text(state.seatLabel(seat.id),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text('$cardCount cards',
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}

/// Floats over the table for ~5.5s after every ask/declare. There's
/// deliberately no persistent log — that would defeat the memory aspect of
/// Literature.
class _AnnouncementOverlay extends StatefulWidget {
  const _AnnouncementOverlay({required this.state});
  final LitGameState state;

  @override
  State<_AnnouncementOverlay> createState() => _AnnouncementOverlayState();
}

class _AnnouncementOverlayState extends State<_AnnouncementOverlay> {
  LitLogEntry? _showing;
  Timer? _timer;

  @override
  void didUpdateWidget(_AnnouncementOverlay old) {
    super.didUpdateWidget(old);
    _maybeShowLatest();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowLatest());
  }

  void _maybeShowLatest() {
    final newest =
        widget.state.log.isEmpty ? null : widget.state.log.last;
    if (newest == null) return;
    if (newest.kind != 'ask' && newest.kind != 'declare') return;
    // Old-format entries (written by clients running the previous build)
    // don't have structured fields. Skip the overlay for those — there's
    // nothing to render.
    if (newest.askerSeatId == null) return;
    if (_showing != null && _showing!.at == newest.at) return;
    setState(() => _showing = newest);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 5500), () {
      if (mounted) setState(() => _showing = null);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = _showing;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: anim, child: child),
      ),
      child: entry == null
          ? const SizedBox.shrink(key: ValueKey('empty'))
          : _AnnouncementCard(
              key: ValueKey(entry.at.toIso8601String()),
              entry: entry,
              state: widget.state,
            ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({
    super.key,
    required this.entry,
    required this.state,
  });
  final LitLogEntry entry;
  final LitGameState state;

  @override
  Widget build(BuildContext context) {
    if (entry.kind == 'ask') return _buildAsk(context);
    if (entry.kind == 'declare') return _buildDeclare(context);
    return const SizedBox.shrink();
  }

  Widget _buildAsk(BuildContext context) {
    final asker = state.seatLabel(entry.askerSeatId!);
    final target = state.seatLabel(entry.targetSeatId!);
    final card =
        entry.cardId == null ? null : PlayingCard.fromId(entry.cardId!);
    final success = entry.success ?? false;
    final accent = success ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    final result = success ? 'GOT IT' : 'NO — TURN PASSES';
    return _shell(
      accent: accent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(asker,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              Icon(success ? Icons.arrow_forward : Icons.arrow_forward,
                  color: accent, size: 28),
              const SizedBox(width: 12),
              Flexible(
                child: Text(target,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (card != null)
            _AnimatedAskCard(card: card, success: success, accent: accent),
          const SizedBox(height: 12),
          Text(result,
              style: TextStyle(
                  color: accent,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildDeclare(BuildContext context) {
    final declarer = state.seatLabel(entry.askerSeatId!);
    final hs = HalfSuites.byId(entry.halfSuiteId!);
    final correct = entry.success ?? false;
    final accent = correct ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    final winnerTeamLabel = entry.winnerTeam == 'a' ? 'Team A' : 'Team B';
    return _shell(
      accent: accent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(declarer,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('declared',
              style: TextStyle(color: Colors.white60, fontSize: 14)),
          const SizedBox(height: 4),
          Text(hs.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text(correct ? '✓ CORRECT' : '✗ WRONG',
              style: TextStyle(
                  color: accent,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2)),
          const SizedBox(height: 4),
          Text('$winnerTeamLabel wins it',
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _shell({required Color accent, required Widget child}) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xFF06180F).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent, width: 3),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.35),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Slides the asked-for card across with a small bounce, signalling the
/// transfer (or, on a failed ask, a quick shake instead).
class _AnimatedAskCard extends StatefulWidget {
  const _AnimatedAskCard({
    required this.card,
    required this.success,
    required this.accent,
  });
  final PlayingCard card;
  final bool success;
  final Color accent;

  @override
  State<_AnimatedAskCard> createState() => _AnimatedAskCardState();
}

class _AnimatedAskCardState extends State<_AnimatedAskCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _shake;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _slide = Tween<Offset>(
      begin: const Offset(-1.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _shake = Tween<double>(begin: 0, end: 1).animate(_ctrl);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.success) {
      return SlideTransition(
        position: _slide,
        child: CardWidget(card: widget.card, size: 70),
      );
    }
    // Failed ask: shake gently.
    return AnimatedBuilder(
      animation: _shake,
      builder: (_, child) {
        final t = _shake.value;
        final dx = (t < 1)
            ? (8 *
                (t < 0.5 ? t : 1 - t) *
                ((t * 8) % 2 < 1 ? 1 : -1))
            : 0.0;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: CardWidget(card: widget.card, size: 70),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.state, required this.controller});
  final LitGameState state;
  final LitController controller;

  @override
  Widget build(BuildContext context) {
    final mySeatId = controller.mySeatId;
    if (mySeatId == null) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('No seat assigned.', style: TextStyle(color: Colors.white)),
      );
    }
    final mySeat = state.seatById(mySeatId);
    final myTurn = state.currentSeatId == mySeatId;
    final myTeamTurn = state.currentSeatId != null &&
        state.seatById(state.currentSeatId!).team == mySeat.team;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              myTurn
                  ? "It's your turn — pick a card to ask for"
                  : 'Turn: ${state.seatLabel(state.currentSeatId!)} (${state.seatById(state.currentSeatId!).team.label})',
              style: TextStyle(
                  color: myTurn ? const Color(0xFF22C55E) : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
          ),
          ElevatedButton.icon(
            onPressed: myTurn
                ? () => _showAskDialog(context, controller, state, mySeatId)
                : null,
            icon: const Icon(Icons.help_outline),
            label: const Text('Ask'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: myTeamTurn
                ? () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider.value(
                          value: controller,
                          child: LitDeclareScreen(declarerSeatId: mySeatId),
                        ),
                      ),
                    );
                  }
                : null,
            icon: const Icon(Icons.flag),
            label: const Text('Declare'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.amber,
              side: const BorderSide(color: Colors.amber),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showAskDialog(
  BuildContext context,
  LitController controller,
  LitGameState state,
  String mySeatId,
) async {
  final myTeam = state.seatById(mySeatId).team;
  final myHand = state.handFor(mySeatId);
  final oppSeats = state
      .seatsOnTeam(myTeam.opponent)
      .where((s) => (state.hands[s.id]?.isNotEmpty ?? false))
      .toList();
  if (oppSeats.isEmpty) return;
  final myHalfSuites =
      HalfSuites.all.where((hs) => myHand.any(hs.contains)).toList();
  if (myHalfSuites.isEmpty) return;

  String targetSeatId = oppSeats.first.id;
  String halfSuiteId = myHalfSuites.first.id;
  PlayingCard? selectedCard;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final hs = HalfSuites.byId(halfSuiteId);
        final selectableCards =
            hs.cards.where((c) => !myHand.contains(c)).toList();
        if (selectedCard != null && !selectableCards.contains(selectedCard)) {
          selectedCard = null;
        }
        return AlertDialog(
          backgroundColor: const Color(0xFF1A3A2A),
          title: const Text('Ask for a card',
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Ask which opponent?',
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: oppSeats
                      .map((seatRef) => ChoiceChip(
                            label: Text(state.seatLabel(seatRef.id)),
                            selected: targetSeatId == seatRef.id,
                            onSelected: (_) =>
                                setState(() => targetSeatId = seatRef.id),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                const Text('Half-suite:',
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: myHalfSuites
                      .map((h) => ChoiceChip(
                            label: Text(h.name),
                            selected: halfSuiteId == h.id,
                            onSelected: (_) =>
                                setState(() => halfSuiteId = h.id),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                const Text('Which card?',
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: selectableCards
                      .map((c) => GestureDetector(
                            onTap: () => setState(() => selectedCard = c),
                            child: CardWidget(
                              card: c,
                              size: 44,
                              selected: selectedCard == c,
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedCard == null
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      await controller.ask(
                        askerSeatId: mySeatId,
                        targetSeatId: targetSeatId,
                        card: selectedCard!,
                      );
                    },
              child: const Text('Ask'),
            ),
          ],
        );
      },
    ),
  );
}

class _HandPane extends StatelessWidget {
  const _HandPane({required this.state, required this.controller});
  final LitGameState state;
  final LitController controller;

  @override
  Widget build(BuildContext context) {
    final mySeatId = controller.mySeatId;
    if (mySeatId == null) return const SizedBox.shrink();
    final hand = state.handFor(mySeatId);
    final byHs = <String, List<PlayingCard>>{};
    for (final c in hand) {
      byHs.putIfAbsent(HalfSuites.forCard(c).id, () => []).add(c);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF06180F),
        border: Border(top: BorderSide(color: Colors.white24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              'Your hand (${state.seatLabel(mySeatId)}, ${hand.length} cards)',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          SizedBox(
            height: 92,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final hsId in byHs.keys) ...[
                  _HandGroup(
                      label: HalfSuites.byId(hsId).name, cards: byHs[hsId]!),
                  const SizedBox(width: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HandGroup extends StatelessWidget {
  const _HandGroup({required this.label, required this.cards});
  final String label;
  final List<PlayingCard> cards;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ),
        Row(
          children: [
            for (final c in cards) ...[
              CardWidget(card: c, size: 48),
              const SizedBox(width: 4),
            ],
          ],
        ),
      ],
    );
  }
}

class _FinishedScreen extends StatelessWidget {
  const _FinishedScreen({required this.state});
  final LitGameState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E2A1E),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, color: Colors.amber, size: 80),
            const SizedBox(height: 16),
            Text('${state.winner?.label ?? "Nobody"} wins!',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
                'Final: A ${state.teamScore(TeamId.a)} — B ${state.teamScore(TeamId.b)}',
                style: const TextStyle(color: Colors.white70, fontSize: 18)),
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controller.dart';
import '../models.dart';
import 'lit_game_screen.dart';

class LitLobbyScreen extends StatelessWidget {
  const LitLobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LitController>(
      builder: (context, ctrl, _) {
        final s = ctrl.state;
        if (s == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (s.phase == LitPhase.playing || s.phase == LitPhase.finished) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: ctrl,
                  child: const LitGameScreen(),
                ),
              ),
            );
          });
        }
        final isHost = ctrl.myPlayerId == s.hostId;
        return Scaffold(
          backgroundColor: const Color(0xFF0E2A1E),
          appBar: AppBar(
            title: Text('Literature lobby — ${s.gameId}'),
            backgroundColor: const Color(0xFF0E2A1E),
            foregroundColor: Colors.white,
          ),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text('Game code: ${s.gameId}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                letterSpacing: 4,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          ctrl.isLocalMode
                              ? 'Local hot-seat: add 5 more players, then assign seats.'
                              : 'Share this code. Pair players on a seat to play "as one".',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                if (ctrl.isLocalMode) _LocalAddPlayer(controller: ctrl),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _TeamColumn(team: TeamId.a, state: s, controller: ctrl)),
                      const VerticalDivider(width: 1, color: Colors.white24),
                      Expanded(child: _TeamColumn(team: TeamId.b, state: s, controller: ctrl)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: isHost ? () => ctrl.startGame() : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 32),
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(isHost
                        ? 'Start game (deal cards)'
                        : 'Waiting for host…'),
                  ),
                ),
                if (ctrl.lastError != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(ctrl.lastError!,
                        style: const TextStyle(color: Colors.amber)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LocalAddPlayer extends StatefulWidget {
  const _LocalAddPlayer({required this.controller});
  final LitController controller;

  @override
  State<_LocalAddPlayer> createState() => _LocalAddPlayerState();
}

class _LocalAddPlayerState extends State<_LocalAddPlayer> {
  final _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Add another local player…',
                hintStyle: TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white38),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              final name = _ctrl.text.trim();
              if (name.isEmpty) return;
              await widget.controller.addLocalPlayer(name);
              _ctrl.clear();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _TeamColumn extends StatelessWidget {
  const _TeamColumn(
      {required this.team, required this.state, required this.controller});
  final TeamId team;
  final LitGameState state;
  final LitController controller;

  @override
  Widget build(BuildContext context) {
    final seats = state.seatsOnTeam(team);
    final color = team == TeamId.a
        ? const Color(0xFF60A5FA)
        : const Color(0xFFF87171);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(team.label,
              style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...seats.map((seat) => _SeatTile(seat: seat, state: state)),
          const SizedBox(height: 12),
          const Text('Unseated', style: TextStyle(color: Colors.white70)),
          ...state.players.values
              .where((p) => !state.seats.any((s) => s.playerIds.contains(p.id)))
              .map((p) => _UnseatedPlayer(
                  player: p, team: team, state: state, controller: controller)),
        ],
      ),
    );
  }
}

class _SeatTile extends StatelessWidget {
  const _SeatTile({required this.seat, required this.state});
  final LitSeat seat;
  final LitGameState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(seat.id,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          if (seat.playerIds.isEmpty)
            const Text('(empty)', style: TextStyle(color: Colors.white54)),
          ...seat.playerIds.map((pid) {
            final p = state.players[pid];
            return Row(
              children: [
                const Icon(Icons.person, size: 14, color: Colors.white70),
                const SizedBox(width: 4),
                Text(p?.name ?? '?',
                    style: const TextStyle(color: Colors.white)),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _UnseatedPlayer extends StatelessWidget {
  const _UnseatedPlayer({
    required this.player,
    required this.team,
    required this.state,
    required this.controller,
  });
  final LitPlayer player;
  final TeamId team;
  final LitGameState state;
  final LitController controller;

  @override
  Widget build(BuildContext context) {
    final seats = state.seatsOnTeam(team);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 4,
        children: [
          Text(player.name, style: const TextStyle(color: Colors.white)),
          ...seats.map((seat) => OutlinedButton(
                onPressed: () =>
                    controller.sit(playerId: player.id, seatId: seat.id),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white38),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 0),
                ),
                child: Text('→ ${seat.id}'),
              )),
        ],
      ),
    );
  }
}

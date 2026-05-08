import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/invite.dart';
import '../controller.dart';
import '../models.dart';
import 'cambio_game_screen.dart';

class CambioLobbyScreen extends StatelessWidget {
  const CambioLobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CambioController>(
      builder: (context, ctrl, _) {
        final s = ctrl.state;
        if (s == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (s.phase != CambioPhase.lobby) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: ctrl,
                  child: const CambioGameScreen(),
                ),
              ),
            );
          });
        }
        final isHost = ctrl.myPlayerId == s.hostId;
        return Scaffold(
          backgroundColor: const Color(0xFF2D1B69),
          appBar: AppBar(
            title: Text('Cambio lobby — ${s.gameId}'),
            backgroundColor: const Color(0xFF2D1B69),
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
                              ? 'Local hot-seat: add 1+ more players, then start.'
                              : 'Share this code. 2+ players to start.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                        if (!ctrl.isLocalMode) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await copyInviteLink(
                                  game: 'cambio', code: s.gameId);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Invite link copied')),
                                );
                              }
                            },
                            icon: const Icon(Icons.link),
                            label: const Text('Copy invite link'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white38),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (ctrl.isLocalMode) _LocalAddPlayer(controller: ctrl),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      const Text('Players (turn order)',
                          style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...s.players.asMap().entries.map((e) {
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: const Color(0xFFA855F7),
                                child: Text('${e.key + 1}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(e.value.name,
                                    style: const TextStyle(color: Colors.white)),
                              ),
                              if (e.value.isHost)
                                const Icon(Icons.star,
                                    color: Colors.amber, size: 16),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: isHost && s.players.length >= 2
                        ? () => ctrl.startGame()
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 32),
                      backgroundColor: const Color(0xFFA855F7),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(isHost
                        ? (s.players.length < 2
                            ? 'Need 2+ players'
                            : 'Start game')
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
  final CambioController controller;

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
                    borderSide: BorderSide(color: Colors.white38)),
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

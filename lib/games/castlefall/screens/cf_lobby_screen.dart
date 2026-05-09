import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/invite.dart';
import '../controller.dart';
import '../models.dart';
import '../word_bank.dart';
import 'cf_game_screen.dart';

class CfLobbyScreen extends StatefulWidget {
  const CfLobbyScreen({super.key});

  @override
  State<CfLobbyScreen> createState() => _CfLobbyScreenState();
}

class _CfLobbyScreenState extends State<CfLobbyScreen> {
  String _category = castlefallBank.first.name;

  @override
  Widget build(BuildContext context) {
    return Consumer<CfController>(
      builder: (context, ctrl, _) {
        final s = ctrl.state;
        if (s == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (s.phase != CfPhase.lobby) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: ctrl,
                  child: const CfGameScreen(),
                ),
              ),
            );
          });
        }
        final isHost = ctrl.myPlayerId == s.hostId;
        return Scaffold(
          backgroundColor: const Color(0xFF1F2A44),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1F2A44),
            foregroundColor: Colors.white,
            title: Text('Castlefall lobby — ${s.gameId}'),
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
                              ? 'Local hot-seat: add 3+ more players, then start.'
                              : 'Share this code. 4+ players to start.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                        if (!ctrl.isLocalMode) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await copyInviteLink(
                                  game: 'castlefall', code: s.gameId);
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
                              side:
                                  const BorderSide(color: Colors.white38),
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
                      const Text('Players',
                          style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...s.players.asMap().entries.map((e) => Container(
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
                                  backgroundColor: const Color(0xFF60A5FA),
                                  child: Text('${e.key + 1}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(e.value.name,
                                      style: const TextStyle(
                                          color: Colors.white)),
                                ),
                                if (e.value.isHost)
                                  const Icon(Icons.star,
                                      color: Colors.amber, size: 16),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Word category:',
                          style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: castlefallBank
                            .map((c) => ChoiceChip(
                                  selected: c.name == _category,
                                  onSelected: isHost
                                      ? (_) =>
                                          setState(() => _category = c.name)
                                      : null,
                                  label: Text(c.name),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: isHost && s.players.length >= 4
                        ? () => ctrl.startRound(_category)
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 32),
                      backgroundColor: const Color(0xFF60A5FA),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(isHost
                        ? (s.players.length < 4
                            ? 'Need 4+ players'
                            : 'Start round')
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
  final CfController controller;

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

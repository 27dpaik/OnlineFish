import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'games/cambio/controller.dart';
import 'games/cambio/models.dart';
import 'games/cambio/screens/cambio_lobby_screen.dart';
import 'games/literature/controller.dart';
import 'games/literature/models.dart';
import 'games/literature/screens/lit_lobby_screen.dart';
import 'games/one_card/controller.dart';
import 'games/one_card/models.dart';
import 'games/one_card/screens/oc_lobby_screen.dart';
import 'shared/sync/firestore_sync.dart';
import 'shared/sync/local_sync.dart';

enum GameKind { literature, oneCard, cambio }

extension on GameKind {
  String get title {
    switch (this) {
      case GameKind.literature:
        return 'Literature';
      case GameKind.oneCard:
        return 'One Card';
      case GameKind.cambio:
        return 'Cambio';
    }
  }

  String get tagline {
    switch (this) {
      case GameKind.literature:
        return '6+ players · 2 teams · ask & declare half-suites';
      case GameKind.oneCard:
        return '2+ players · attacks, shields, and a wild 7';
      case GameKind.cambio:
        return '2+ players · memory, peeks, and the race to call cambio';
    }
  }

  Color get color {
    switch (this) {
      case GameKind.literature:
        return const Color(0xFF22C55E);
      case GameKind.oneCard:
        return const Color(0xFF3B82F6);
      case GameKind.cambio:
        return const Color(0xFFA855F7);
    }
  }

  IconData get icon {
    switch (this) {
      case GameKind.literature:
        return Icons.style;
      case GameKind.oneCard:
        return Icons.swap_horiz;
      case GameKind.cambio:
        return Icons.visibility_off;
    }
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.firebaseReady,
    this.initialGameKind,
    this.initialCode,
  });
  final bool firebaseReady;
  final GameKind? initialGameKind;
  final String? initialCode;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.initialGameKind != null && widget.initialCode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => GameEntryScreen(
            kind: widget.initialGameKind!,
            firebaseReady: widget.firebaseReady,
            initialCode: widget.initialCode,
          ),
        ));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseReady = widget.firebaseReady;
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  const SizedBox(height: 28),
                  const Text(
                    'OnlineFish',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const Text(
                    'Three card games, one app',
                    style: TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  if (!firebaseReady)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: const Text(
                        'Online play is unavailable: Firebase not configured. '
                        'See README for setup. Local hot-seat works.',
                        style: TextStyle(color: Colors.amber, fontSize: 12),
                      ),
                    ),
                  for (final kind in GameKind.values) ...[
                    _GameCard(
                      kind: kind,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GameEntryScreen(
                            kind: kind,
                            firebaseReady: firebaseReady,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.kind, required this.onTap});
  final GameKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kind.color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: kind.color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(kind.icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(kind.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(kind.tagline,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}

class GameEntryScreen extends StatefulWidget {
  const GameEntryScreen({
    super.key,
    required this.kind,
    required this.firebaseReady,
    this.initialCode,
  });
  final GameKind kind;
  final bool firebaseReady;
  final String? initialCode;

  @override
  State<GameEntryScreen> createState() => _GameEntryScreenState();
}

class _GameEntryScreenState extends State<GameEntryScreen> {
  late final _name = TextEditingController();
  late final _code = TextEditingController(text: widget.initialCode ?? '');
  bool _busy = false;
  bool get _arrivedViaInvite => widget.initialCode != null;

  Future<void> _go({required bool host, required bool online}) async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    if (!host && _code.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      switch (widget.kind) {
        case GameKind.literature:
          await _startLit(host: host, online: online, name: name);
          break;
        case GameKind.oneCard:
          await _startOc(host: host, online: online, name: name);
          break;
        case GameKind.cambio:
          await _startCambio(host: host, online: online, name: name);
          break;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startLit({
    required bool host,
    required bool online,
    required String name,
  }) async {
    final sync = online
        ? FirestoreSync<LitGameState>(
            collection: 'lit_games',
            toJson: (s) => s.toJson(),
            fromJson: LitGameState.fromJson,
          )
        : LocalSync<LitGameState>();
    final ctrl = LitController(sync);
    if (host) {
      final code = await ctrl.createGame(hostName: name);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Code: $code')));
      }
    } else {
      await ctrl.joinGame(code: _code.text.trim().toUpperCase(), name: name);
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(
        value: ctrl,
        child: const LitLobbyScreen(),
      ),
    ));
  }

  Future<void> _startOc({
    required bool host,
    required bool online,
    required String name,
  }) async {
    final sync = online
        ? FirestoreSync<OcState>(
            collection: 'oc_games',
            toJson: (s) => s.toJson(),
            fromJson: OcState.fromJson,
          )
        : LocalSync<OcState>();
    final ctrl = OcController(sync);
    if (host) {
      final code = await ctrl.createGame(hostName: name);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Code: $code')));
      }
    } else {
      await ctrl.joinGame(code: _code.text.trim().toUpperCase(), name: name);
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(
        value: ctrl,
        child: const OcLobbyScreen(),
      ),
    ));
  }

  Future<void> _startCambio({
    required bool host,
    required bool online,
    required String name,
  }) async {
    final sync = online
        ? FirestoreSync<CambioState>(
            collection: 'cambio_games',
            toJson: (s) => s.toJson(),
            fromJson: CambioState.fromJson,
          )
        : LocalSync<CambioState>();
    final ctrl = CambioController(sync);
    if (host) {
      final code = await ctrl.createGame(hostName: name);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Code: $code')));
      }
    } else {
      await ctrl.joinGame(code: _code.text.trim().toUpperCase(), name: name);
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(
        value: ctrl,
        child: const CambioLobbyScreen(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final firebase = widget.firebaseReady;
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        foregroundColor: Colors.white,
        title: Text(widget.kind.title),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  if (_arrivedViaInvite)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: widget.kind.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: widget.kind.color),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'You were invited to game ${widget.initialCode}',
                            style: TextStyle(
                                color: widget.kind.color,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Type your name and tap "Join online game".',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  _whiteField(_name, 'Your name'),
                  const SizedBox(height: 12),
                  _whiteField(_code, 'Game code (to join)'),
                  const SizedBox(height: 28),
                  _bigButton(
                    color: widget.kind.color,
                    label: 'Host online game',
                    icon: Icons.cloud_upload,
                    onPressed: firebase && !_busy
                        ? () => _go(host: true, online: true)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _bigButton(
                    color: widget.kind.color,
                    label: 'Join online game',
                    icon: Icons.cloud_download,
                    onPressed: firebase && !_busy
                        ? () => _go(host: false, online: true)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _bigButton(
                    color: const Color(0xFF374151),
                    label: 'Local hot-seat game',
                    icon: Icons.phone_android,
                    onPressed:
                        !_busy ? () => _go(host: true, online: false) : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _whiteField(TextEditingController c, String label) => TextField(
        controller: c,
        style: const TextStyle(color: Colors.white),
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white38)),
          focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white)),
        ),
      );

  Widget _bigButton({
    required Color color,
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) =>
      ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: color,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      );
}

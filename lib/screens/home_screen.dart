import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/firestore_game_service.dart';
import '../services/local_game_service.dart';
import '../state/game_controller.dart';
import 'lobby_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.firebaseReady});
  final bool firebaseReady;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _nameCtrl = TextEditingController(text: '');
  final _codeCtrl = TextEditingController();
  bool _busy = false;

  Future<void> _enter(GameController controller) async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: controller,
          child: const LobbyScreen(),
        ),
      ),
    );
  }

  Future<void> _hostOnline() async {
    if (!widget.firebaseReady) return;
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final svc = FirestoreGameService();
      final ctrl = GameController(svc);
      final code = await ctrl.createGame(hostName: _nameCtrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Game code: $code')),
      );
      await _enter(ctrl);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _joinOnline() async {
    if (!widget.firebaseReady) return;
    if (_nameCtrl.text.trim().isEmpty || _codeCtrl.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final svc = FirestoreGameService();
      final ctrl = GameController(svc);
      await ctrl.joinGame(
        code: _codeCtrl.text.trim().toUpperCase(),
        name: _nameCtrl.text.trim(),
      );
      await _enter(ctrl);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _localGame() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final svc = LocalGameService();
      final ctrl = GameController(svc);
      await ctrl.createGame(hostName: _nameCtrl.text.trim());
      await _enter(ctrl);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebase = widget.firebaseReady;
    return Scaffold(
      backgroundColor: const Color(0xFF0E2A1E),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  const Text(
                    'Literature',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 56,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const Text(
                    'a.k.a. Fish — 6 players, 2 teams, 9 half-suites',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 40),
                  _whiteField(_nameCtrl, 'Your name'),
                  const SizedBox(height: 12),
                  _whiteField(_codeCtrl, 'Game code (to join)'),
                  const SizedBox(height: 28),
                  if (!firebase)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: const Text(
                        'Online play unavailable: Firebase not configured. '
                        'See README for setup. Local mode still works.',
                        style: TextStyle(color: Colors.amber, fontSize: 12),
                      ),
                    ),
                  _bigButton(
                    label: 'Host online game',
                    icon: Icons.cloud_upload,
                    onPressed: firebase && !_busy ? _hostOnline : null,
                  ),
                  const SizedBox(height: 12),
                  _bigButton(
                    label: 'Join online game',
                    icon: Icons.cloud_download,
                    onPressed: firebase && !_busy ? _joinOnline : null,
                  ),
                  const SizedBox(height: 12),
                  _bigButton(
                    label: 'Local hot-seat game',
                    icon: Icons.phone_android,
                    onPressed: !_busy ? _localGame : null,
                    secondary: true,
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
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white38),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white),
          ),
        ),
      );

  Widget _bigButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool secondary = false,
  }) =>
      ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor:
              secondary ? const Color(0xFF374151) : const Color(0xFF22C55E),
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      );
}

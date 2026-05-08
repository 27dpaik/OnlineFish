import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/card_widget.dart';
import '../controller.dart';
import '../half_suite.dart';

class LitDeclareScreen extends StatefulWidget {
  const LitDeclareScreen({super.key, required this.declarerSeatId});
  final String declarerSeatId;

  @override
  State<LitDeclareScreen> createState() => _LitDeclareScreenState();
}

class _LitDeclareScreenState extends State<LitDeclareScreen> {
  String? _halfSuiteId;
  final Map<String, String> _assignment = {};

  @override
  Widget build(BuildContext context) {
    return Consumer<LitController>(
      builder: (context, ctrl, _) {
        final s = ctrl.state;
        if (s == null) return const SizedBox.shrink();
        final myTeam = s.seatById(widget.declarerSeatId).team;
        final teamSeats = s.seatsOnTeam(myTeam);
        final available = HalfSuites.all
            .where((hs) => !s.claimedHalfSuites.containsKey(hs.id))
            .toList();
        final hs = _halfSuiteId == null ? null : HalfSuites.byId(_halfSuiteId!);
        return Scaffold(
          backgroundColor: const Color(0xFF0E2A1E),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0E2A1E),
            foregroundColor: Colors.white,
            title: const Text('Declare a half-suite'),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pick a half-suite to declare. You must specify which '
                    'teammate (or yourself) holds each card.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: available
                        .map((h) => ChoiceChip(
                              selected: _halfSuiteId == h.id,
                              onSelected: (_) => setState(() {
                                _halfSuiteId = h.id;
                                _assignment.clear();
                              }),
                              label: Text(h.name),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  if (hs != null)
                    Expanded(
                      child: ListView(
                        children: hs.cards.map((c) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                CardWidget(card: c, size: 44),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: teamSeats
                                        .map((seat) => ChoiceChip(
                                              selected:
                                                  _assignment[c.id] == seat.id,
                                              onSelected: (_) => setState(() {
                                                _assignment[c.id] = seat.id;
                                              }),
                                              label: Text(s.seatLabel(seat.id)),
                                            ))
                                        .toList(),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  if (hs == null)
                    const Expanded(
                      child: Center(
                        child: Text('Pick a half-suite above',
                            style: TextStyle(color: Colors.white54)),
                      ),
                    ),
                  Row(
                    children: [
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: hs == null ||
                                _assignment.length != hs.cards.length
                            ? null
                            : () async {
                                await ctrl.declare(
                                  declarerSeatId: widget.declarerSeatId,
                                  halfSuiteId: _halfSuiteId!,
                                  assignment:
                                      Map<String, String>.from(_assignment),
                                );
                                if (context.mounted) Navigator.pop(context);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('Declare'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

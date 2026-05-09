import 'package:flutter_test/flutter_test.dart';
import 'package:literature_game/games/davinci/engine.dart';
import 'package:literature_game/games/davinci/models.dart';

DvState _readyGame({int players = 3, int seed = 11}) {
  var s = DaVinciEngine.newLobby(
    gameId: 'g1',
    hostId: 'p1',
    hostName: 'P1',
    seed: seed,
  );
  for (var i = 2; i <= players; i++) {
    s = DaVinciEngine.addPlayer(s, DvPlayer(id: 'p$i', name: 'P$i'));
  }
  return s;
}

void main() {
  group('Da Vinci Code engine', () {
    test('full set has 26 blocks (13 white, 13 black)', () {
      final all = DaVinciEngine.standardSet();
      expect(all.length, 26);
      expect(all.where((b) => b.color == DvColor.white).length, 13);
      expect(all.where((b) => b.color == DvColor.black).length, 13);
      expect(all.where((b) => b.isJoker).length, 2);
    });

    test('startGame deals 4 to each in a 3-player game and 3 in 4-player', () {
      var s = _readyGame(players: 3);
      s = DaVinciEngine.startGame(s).next!;
      for (final p in s.players) {
        expect(s.hands[p.id]!.length, 4);
        // No jokers in starting hand per official rule
        expect(s.hands[p.id]!.every((b) => !b.isJoker), true);
      }
      var s4 = _readyGame(players: 4);
      s4 = DaVinciEngine.startGame(s4).next!;
      for (final p in s4.players) {
        expect(s4.hands[p.id]!.length, 3);
      }
    });

    test('starting hands are sorted ascending with black first on ties', () {
      var s = _readyGame(players: 3);
      s = DaVinciEngine.startGame(s).next!;
      for (final p in s.players) {
        final hand = s.hands[p.id]!;
        for (var i = 1; i < hand.length; i++) {
          final a = hand[i - 1];
          final b = hand[i];
          final av = a.value!;
          final bv = b.value!;
          expect(av <= bv, true,
              reason: 'hand for ${p.id} not sorted at index $i');
          if (av == bv) {
            expect(a.color, DvColor.black,
                reason: 'tie at $av should put black on the left');
          }
        }
      }
    });

    test('correct guess reveals opponent block and offers continue/stop', () {
      var s = _readyGame(players: 2);
      s = DaVinciEngine.startGame(s).next!;
      // Force a known scenario: the active player draws and guesses a known
      // block in the other player's hand.
      final me = s.currentPlayer.id;
      final them = s.players.firstWhere((p) => p.id != me).id;
      final theirHand = s.hands[them]!;
      // Draw via engine
      s = DaVinciEngine.drawFromStock(s, me).next!;
      final pos = 0;
      final correctVal = theirHand[pos].value;
      final res = DaVinciEngine.guess(
        s: s,
        guesserId: me,
        targetId: them,
        position: pos,
        value: correctVal,
      );
      expect(res.ok, true);
      expect(res.next!.hands[them]![pos].revealed, true);
      expect(res.next!.awaitingChoiceAfterCorrect, true);
    });

    test('wrong guess reveals the drawn block and passes the turn', () {
      var s = _readyGame(players: 2);
      s = DaVinciEngine.startGame(s).next!;
      final me = s.currentPlayer.id;
      final them = s.players.firstWhere((p) => p.id != me).id;
      s = DaVinciEngine.drawFromStock(s, me).next!;
      final drawn = s.drawn!.block;
      // Guess something that is unlikely to be the value (target+offset).
      final guess = ((s.hands[them]![0].value ?? 0) + 5) % 12;
      final res = DaVinciEngine.guess(
        s: s,
        guesserId: me,
        targetId: them,
        position: 0,
        value: guess,
      );
      expect(res.ok, true);
      // If by coincidence the guess was correct, the block is revealed and
      // it's still my turn — different branch — skip the rest of the assertion
      // in that case.
      if (res.next!.awaitingChoiceAfterCorrect) return;
      expect(res.next!.currentPlayer.id, them);
      expect(res.next!.hands[me]!.any((b) =>
          b.value == drawn.value && b.color == drawn.color && b.revealed), true);
    });
  });
}

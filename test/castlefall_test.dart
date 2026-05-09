import 'package:flutter_test/flutter_test.dart';
import 'package:literature_game/games/castlefall/engine.dart';
import 'package:literature_game/games/castlefall/models.dart';

CfState _readyGame({int players = 4}) {
  var s = CastlefallEngine.newLobby(
    gameId: 'g1',
    hostId: 'p1',
    hostName: 'P1',
    seed: 7,
  );
  for (var i = 2; i <= players; i++) {
    s = CastlefallEngine.addPlayer(s, CfPlayer(id: 'p$i', name: 'P$i'));
  }
  return s;
}

void main() {
  group('Castlefall engine', () {
    test('startRound deals 16 words, 2 distinct team words, splits teams', () {
      var s = _readyGame(players: 6);
      final res = CastlefallEngine.startRound(s, 'Food');
      expect(res.ok, true);
      s = res.next!;
      expect(s.phase, CfPhase.playing);
      final round = s.round!;
      expect(round.wordList.length, 16);
      expect(round.wordA, isNot(round.wordB));
      expect(round.teamA.length + round.teamB.length, 6);
      // every player on exactly one team
      final ids = {...round.teamA, ...round.teamB};
      expect(ids.length, 6);
    });

    test('rejects rounds with fewer than 4 players', () {
      var s = _readyGame(players: 3);
      final res = CastlefallEngine.startRound(s, 'Food');
      expect(res.ok, false);
    });

    test('correct method-1 declaration wins', () {
      var s = _readyGame(players: 4);
      s = CastlefallEngine.startRound(s, 'Food').next!;
      final declarer = s.round!.teamA.first;
      // Claim declarer's actual team — should be correct.
      final res = CastlefallEngine.declareTeam(
        s: s,
        declarerId: declarer,
        claimedPlayerIds: s.round!.teamA,
      );
      expect(res.ok, true);
      final resolved = CastlefallEngine.resolveTeamDeclaration(res.next!);
      expect(resolved.ok, true);
      expect(resolved.next!.declaration!.success, true);
    });

    test('wrong method-1 declaration loses', () {
      var s = _readyGame(players: 4);
      s = CastlefallEngine.startRound(s, 'Food').next!;
      final declarer = s.round!.teamA.first;
      // Include an opposing-team player → wrong.
      final claim = [declarer, s.round!.teamB.first];
      final res = CastlefallEngine.declareTeam(
        s: s,
        declarerId: declarer,
        claimedPlayerIds: claim,
      );
      final resolved = CastlefallEngine.resolveTeamDeclaration(res.next!);
      expect(resolved.next!.declaration!.success, false);
    });

    test('correct word guess wins immediately', () {
      var s = _readyGame(players: 4);
      s = CastlefallEngine.startRound(s, 'Food').next!;
      final declarer = s.round!.teamA.first;
      final res = CastlefallEngine.guessWord(
        s: s,
        declarerId: declarer,
        guessedWord: s.round!.wordB,
      );
      expect(res.ok, true);
      expect(res.next!.phase, CfPhase.revealed);
      expect(res.next!.declaration!.success, true);
    });
  });
}

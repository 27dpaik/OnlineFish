# Online Fish (Literature)

A Flutter implementation of the team card game **Literature** (a.k.a. Fish):
6 players, 2 teams of 3, a 54-card deck split into 9 half-suites. Ask
opponents for cards, declare half-suites you think you've mapped, and win
more than your opponents.

Two play modes:

- **Local hot-seat** — one device, pass between players. No backend needed,
  works offline.
- **Online** — synced via Firebase Firestore. Each player runs the app and
  joins by game code.

## Game rules

- Standard 52 cards + 2 jokers = 54.
- 6 seats: A1, A2, A3 on Team A; B1, B2, B3 on Team B. Each is dealt 9 cards.
- **More than 6 humans?** Two players can share one seat ("playing as one")
  — both see the same hand and both can play.
- The 9 half-suites:
  1. Lower Spades (2–7)
  2. Lower Hearts (2–7)
  3. Lower Diamonds (2–7)
  4. Lower Clubs (2–7)
  5. Upper Spades (9–A)
  6. Upper Hearts (9–A)
  7. Upper Diamonds (9–A)
  8. Upper Clubs (9–A)
  9. Eights & Jokers (the four 8s + both jokers)
- On your turn, **ask** an opponent for a specific card. You must already
  hold at least one card in that card's half-suite, and you must not already
  hold the card.
  - If they have it: it transfers to you, and you ask again.
  - If they don't: their team takes the turn.
- At any point during your team's turn, anyone on your team can **declare**
  a half-suite by stating which seat on your team holds each of its 6 cards.
  - Correct → your team wins the half-suite.
  - Wrong → the other team wins it.
- Cards in a declared half-suite leave play. The team that won it plays next.
- After all 9 half-suites are claimed, whoever has more wins.

## Project layout

```
lib/
  main.dart
  models/         # PlayingCard, HalfSuite, GameState, Player, Seat, …
  engine/         # Deck, pure rules engine (deal / ask / declare)
  services/       # GameService abstraction + local + Firestore impls
  state/          # GameController (ChangeNotifier glue)
  screens/        # home, lobby, game, declare
  widgets/        # CardWidget
test/             # Engine unit tests + widget smoke test
```

The **engine is pure** — no Flutter, no I/O. UI and network sit on top of
it. That makes the rules easy to test and easy to swap in a different
backend later.

## Running locally

```bash
flutter pub get
flutter run             # iOS / Android / desktop / web
flutter test            # run engine + widget tests
```

Local hot-seat mode works out of the box — pick *Local hot-seat game*, add
players, assign seats, deal.

## Setting up online play (Firebase)

The online mode pushes the game state to Firestore at `games/{code}`. To
enable it for your own copy:

1. **Create a Firebase project** at https://console.firebase.google.com.
2. **Enable Firestore** (Build → Firestore Database → Create in production
   mode is fine).
3. Install the FlutterFire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   ```
4. From the repo root, link this app to your Firebase project:
   ```bash
   flutterfire configure
   ```
   Pick your project and the platforms you care about (iOS, Android, web).
   This generates `lib/firebase_options.dart` and the platform configs
   (`google-services.json`, `GoogleService-Info.plist`).
5. Update `lib/main.dart` so the import + initializer use the generated
   options:
   ```dart
   import 'firebase_options.dart';
   // …
   await Firebase.initializeApp(
     options: DefaultFirebaseOptions.currentPlatform,
   );
   ```
6. **Loosen Firestore rules** (these are permissive — fine for friends-only
   play; tighten before shipping):
   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /games/{code} {
         allow read, write: if true;
       }
     }
   }
   ```

Without these steps the app still launches, but the *Host online* /
*Join online* buttons stay disabled with a notice. Local mode works
regardless.

## Status

This is an MVP. Working:

- Full 9-half-suite rule enforcement (ask validation, declare scoring,
  turn passing, win detection).
- Pairing players on a single seat for inclusive 7+ player games.
- Local hot-seat play.
- Firestore-backed online play (after the setup above).
- Engine unit tests covering deal, ask, declare.

Possible next steps: animations on card transfers, a "who's holding what"
notes panel for declarers, end-of-game stats, anonymous Firebase auth, and
tightened Firestore rules.

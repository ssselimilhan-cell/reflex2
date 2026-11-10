import 'package:flutter_test/flutter_test.dart';
import 'package:stres_kart/game/game_engine.dart';

void main() {
  group('GameEngine baseline invariants', () {
    test('starts with a complete 52-card deck split between both players', () {
      final engine = GameEngine(seed: 42)..startNewGame();

      final cards = <PlayingCard>[
        ...engine.player1Stock,
        ...engine.player2Stock,
        for (final column in engine.columns) ...column,
      ];

      expect(cards, hasLength(52));
      expect(cards.toSet(), hasLength(52));
      expect(engine.player1Stock, hasLength(22));
      expect(engine.player2Stock, hasLength(22));
      expect(engine.columns, hasLength(GameEngine.columnCount));
      expect(engine.columns.every((column) => column.length == 1), isTrue);
      expect(engine.status, GameStatus.playing);
    });

    test('does not allow moves while the opening animation lock is active', () {
      final engine = GameEngine(seed: 42)..startNewGame();

      expect(engine.locked, isTrue);
      expect(
        engine.attemptPlay(PlayerSide.player1, 0),
        isFalse,
      );
      expect(engine.player1Stock, hasLength(22));
    });

    test('serializes and restores the initial game state', () {
      final original = GameEngine(seed: 42)..startNewGame();
      final restored = GameEngine(seed: 7)
        ..loadFromMap(original.toMap());

      expect(restored.player1Stock, original.player1Stock);
      expect(restored.player2Stock, original.player2Stock);
      expect(restored.columns, original.columns);
      expect(restored.activeColumns, original.activeColumns);
      expect(restored.status, original.status);
      expect(restored.streakEventId, original.streakEventId);
    });


    test('rejects malformed state without changing the current game', () {
      final engine = GameEngine(seed: 42)..startNewGame();
      final before = engine.toMap();
      final malformed = Map<String, dynamic>.from(before)
        ..['columns'] = <String>['invalid'];

      expect(
        () => engine.loadFromMap(malformed),
        throwsA(isA<FormatException>()),
      );
      expect(engine.toMap(), before);
    });

    test('rejects duplicate cards in a restored game', () {
      final engine = GameEngine(seed: 42)..startNewGame();
      final malformed = Map<String, dynamic>.from(engine.toMap());
      final stocks = List<String>.from(malformed['player1Stock'] as List);
      stocks[0] = (malformed['player2Stock'] as List<String>)[0];
      malformed['player1Stock'] = stocks;

      expect(
        () => GameEngine().loadFromMap(malformed),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects out-of-range active column indexes', () {
      final engine = GameEngine(seed: 42)..startNewGame();
      final malformed = Map<String, dynamic>.from(engine.toMap())
        ..['unlocked'] = <int>[GameEngine.columnCount];

      expect(
        () => GameEngine().loadFromMap(malformed),
        throwsA(isA<FormatException>()),
      );
    });

    test('standard deck contains every suit and rank exactly once', () {
      final deck = buildStandardDeck();

      expect(deck, hasLength(52));
      expect(deck.map((card) => card.suit).toSet(), hasLength(4));
      expect(deck.map((card) => card.rank).toSet(), hasLength(13));
      expect(deck.map((card) => card.toCode()).toSet(), hasLength(52));
    });
  });
}

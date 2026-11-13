import 'package:flutter_test/flutter_test.dart';
import 'package:stres_kart/settings/ranks.dart';

void main() {
  group('online rank thresholds', () {
    test('bronze starts at zero wins', () {
      expect(rankFor(0).nameKey, 'rank_bronze');
      expect(rankFor(9).nameKey, 'rank_bronze');
    });

    test('rank advances exactly at each threshold', () {
      expect(rankFor(10).nameKey, 'rank_silver');
      expect(rankFor(29).nameKey, 'rank_silver');
      expect(rankFor(30).nameKey, 'rank_gold');
      expect(rankFor(74).nameKey, 'rank_gold');
      expect(rankFor(75).nameKey, 'rank_diamond');
      expect(rankFor(149).nameKey, 'rank_diamond');
      expect(rankFor(150).nameKey, 'rank_legend');
    });

    test('next rank is null only at legend', () {
      expect(nextRankFor(0)?.nameKey, 'rank_silver');
      expect(nextRankFor(10)?.nameKey, 'rank_gold');
      expect(nextRankFor(150), isNull);
    });
  });
}

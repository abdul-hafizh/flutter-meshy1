/// Short grams for "terjual" labels, one decimal rounded down so a total is
/// never overstated: 350 → "350 g", 2350 → "2.3k g", 1250000 → "1.2Jt g".
String shortGrams(int grams) {
  String scaled(int value, int unit, String suffix) {
    final tenths = value * 10 ~/ unit;
    final whole = tenths ~/ 10;
    final decimal = tenths % 10;
    return decimal == 0 ? '$whole$suffix' : '$whole.$decimal$suffix';
  }

  if (grams >= 1000000) return '${scaled(grams, 1000000, 'Jt')} g';
  if (grams >= 1000) return '${scaled(grams, 1000, 'k')} g';
  return '$grams g';
}

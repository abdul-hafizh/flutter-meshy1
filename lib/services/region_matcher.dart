import '../models/region.dart';

/// Matches the free-text region names the phone's geocoder returns
/// ("Daerah Khusus Ibukota Jakarta", "Kabupaten Bandung", "South Jakarta",
/// "West Java" …) against the backend's Country/Province/City rows
/// ("DKI Jakarta", "Kabupaten Bandung", "Kota Jakarta Selatan",
/// "Jawa Barat" …). Names are compared as word sets, so word order and
/// prefixes like "Provinsi"/"DKI" don't matter.
class RegionMatcher {
  RegionMatcher._();

  static const _english = {
    'west': 'barat',
    'east': 'timur',
    'north': 'utara',
    'south': 'selatan',
    'central': 'tengah',
    'southeast': 'tenggara',
    'southwest': 'barat daya',
    'highland': 'pegunungan',
    'java': 'jawa',
    'sumatra': 'sumatera',
    'islands': 'kepulauan',
    'island': 'kepulauan',
    'kep': 'kepulauan',
  };

  /// Words that only say what kind of region it is.
  static const _noise = {
    'provinsi', 'province', 'prov', 'daerah', 'khusus', 'ibukota', 'istimewa',
    'special', 'capital', 'region', 'of', 'dki', 'di', 'administrasi', 'adm',
  };

  static const _cityWords = {'kota', 'city'};
  static const _regencyWords = {'kabupaten', 'kab', 'regency'};

  static Set<String> _words(String raw) {
    final cleaned = raw
        .toLowerCase()
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
    final out = <String>{};
    for (final w in cleaned.split(RegExp(r'\s+'))) {
      if (w.isEmpty) continue;
      out.addAll((_english[w] ?? w).split(' '));
    }
    return out..removeAll(_noise);
  }

  static bool _sameWords(Set<String> a, Set<String> b) =>
      a.isNotEmpty && a.length == b.length && a.containsAll(b);

  static int? country(List<CountryRef> countries, {String? name, String? isoCode}) {
    final wanted = <Set<String>>[
      if (name != null) _words(name),
      if (isoCode?.toUpperCase() == 'ID') {'indonesia'},
      if (isoCode?.toUpperCase() == 'SG') {'singapore'},
      if (isoCode?.toUpperCase() == 'SG') {'singapura'},
    ];
    for (final c in countries) {
      final words = _words(c.name);
      if (wanted.any((w) => _sameWords(w, words))) return c.id;
    }
    return null;
  }

  static int? province(List<ProvinceRef> provinces, String? name) {
    if (name == null || name.trim().isEmpty) return null;
    final wanted = _words(name);
    for (final p in provinces) {
      if (_sameWords(wanted, _words(p.name))) return p.id;
    }
    return null;
  }

  /// Tries each candidate name in order (the geocoder puts the kota/kabupaten
  /// in different fields depending on the area). A "Kota X" vs "Kabupaten X"
  /// mismatch is only accepted when X is unambiguous in the province.
  static int? city(List<CityRef> cities, List<String?> candidates) {
    for (final raw in candidates) {
      if (raw == null || raw.trim().isEmpty) continue;
      final (kind, base) = _cityParts(raw);
      final sameBase = [
        for (final c in cities)
          if (_sameWords(base, _cityParts(c.name).$2)) c,
      ];
      if (sameBase.isEmpty) continue;
      if (kind != null) {
        for (final c in sameBase) {
          if (_cityParts(c.name).$1 == kind) return c.id;
        }
      }
      if (sameBase.length == 1) return sameBase.first.id;
    }
    return null;
  }

  /// ('kota' | 'kabupaten' | null, remaining words)
  static (String?, Set<String>) _cityParts(String name) {
    final words = _words(name);
    String? kind;
    if (words.any(_cityWords.contains)) kind = 'kota';
    if (words.any(_regencyWords.contains)) kind = 'kabupaten';
    return (kind, words..removeAll({..._cityWords, ..._regencyWords}));
  }
}

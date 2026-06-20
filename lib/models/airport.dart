class Airport {
  final String icao;
  final String name;
  final double elevationFt;
  final double latDeg;
  final double lonDeg;

  const Airport({
    required this.icao,
    required this.name,
    required this.elevationFt,
    required this.latDeg,
    required this.lonDeg,
  });

  Map<String, dynamic> toJson() => {
    'icao': icao,
    'name': name,
    'elevationFt': elevationFt,
    'latDeg': latDeg,
    'lonDeg': lonDeg,
  };

  factory Airport.fromJson(Map<String, dynamic> j) => Airport(
    icao: (j['icao'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    elevationFt: (j['elevationFt'] ?? 0).toDouble(),
    latDeg: (j['latDeg'] ?? 0).toDouble(),
    lonDeg: (j['lonDeg'] ?? 0).toDouble(),
  );
}

/// Declared distances for one direction of a runway.
class RunwayDirection {
  final String ident; // e.g. "09", "27L"
  final double toraM; // Take-Off Run Available
  final double todaM; // Take-Off Distance Available
  final double ldaM;  // Landing Distance Available

  const RunwayDirection({
    required this.ident,
    required this.toraM,
    required this.todaM,
    required this.ldaM,
  });

  Map<String, dynamic> toJson() => {
    'ident': ident,
    'toraM': toraM,
    'todaM': todaM,
    'ldaM': ldaM,
  };

  factory RunwayDirection.fromJson(Map<String, dynamic> j) => RunwayDirection(
    ident: (j['ident'] ?? '').toString(),
    toraM: (j['toraM'] ?? 0).toDouble(),
    todaM: (j['todaM'] ?? 0).toDouble(),
    ldaM: (j['ldaM'] ?? 0).toDouble(),
  );

  /// Create from physical length (default when no AIP data available)
  factory RunwayDirection.fromPhysical({required String ident, required double lengthM}) =>
      RunwayDirection(ident: ident, toraM: lengthM, todaM: lengthM, ldaM: lengthM);

  RunwayDirection copyWith({double? toraM, double? todaM, double? ldaM}) => RunwayDirection(
    ident: ident,
    toraM: toraM ?? this.toraM,
    todaM: todaM ?? this.todaM,
    ldaM: ldaM ?? this.ldaM,
  );
}

class Runway {
  final String airportIcao;
  final String leIdent;
  final String heIdent;
  final double lengthM; // physical length
  final double widthM;
  final String surface;
  final bool lighted;
  final RunwayDirection le;
  final RunwayDirection he;

  const Runway({
    required this.airportIcao,
    required this.leIdent,
    required this.heIdent,
    required this.lengthM,
    required this.widthM,
    required this.surface,
    required this.lighted,
    required this.le,
    required this.he,
  });

  String get displayName => '$leIdent / $heIdent';

  Map<String, dynamic> toJson() => {
    'airportIcao': airportIcao,
    'leIdent': leIdent,
    'heIdent': heIdent,
    'lengthM': lengthM,
    'widthM': widthM,
    'surface': surface,
    'lighted': lighted,
    'le': le.toJson(),
    'he': he.toJson(),
  };

  factory Runway.fromJson(Map<String, dynamic> j) {
    final lengthM = (j['lengthM'] ?? 0).toDouble();
    final leIdent = (j['leIdent'] ?? '').toString();
    final heIdent = (j['heIdent'] ?? '').toString();
    return Runway(
      airportIcao: (j['airportIcao'] ?? '').toString(),
      leIdent: leIdent,
      heIdent: heIdent,
      lengthM: lengthM,
      widthM: (j['widthM'] ?? 0).toDouble(),
      surface: (j['surface'] ?? '').toString(),
      lighted: j['lighted'] == true,
      le: j['le'] != null
          ? RunwayDirection.fromJson(Map<String, dynamic>.from(j['le']))
          : RunwayDirection.fromPhysical(ident: leIdent, lengthM: lengthM),
      he: j['he'] != null
          ? RunwayDirection.fromJson(Map<String, dynamic>.from(j['he']))
          : RunwayDirection.fromPhysical(ident: heIdent, lengthM: lengthM),
    );
  }
}

enum SoilType { clay, loam, sandy, silt, peat, unknown }

extension SoilTypeX on SoilType {
  String get bangla {
    switch (this) {
      case SoilType.clay:
        return 'কর্দম মাটি';
      case SoilType.loam:
        return 'দোআঁশ মাটি';
      case SoilType.sandy:
        return 'বেলে মাটি';
      case SoilType.silt:
        return 'পলি মাটি';
      case SoilType.peat:
        return 'জৈব মাটি';
      case SoilType.unknown:
        return 'অজানা';
    }
  }

  String get key => name;
}

/// How the farmer holds / uses this parcel. Bangladeshi reality: many
/// plots are leased-in ("বর্গা") for a season rather than owned.
enum LandOwnership { owned, leased, shared, family }

extension LandOwnershipX on LandOwnership {
  String get bangla {
    switch (this) {
      case LandOwnership.owned:
        return 'নিজস্ব';
      case LandOwnership.leased:
        return 'বর্গা (ইজারা)';
      case LandOwnership.shared:
        return 'যৌথ অংশীদারি';
      case LandOwnership.family:
        return 'পারিবারিক';
    }
  }

  String get key => name;
}

/// Source of irrigation water for this farm. Crop-advisory logic reads
/// this to recommend crops that match the available water supply.
enum WaterSource { rainwater, tubewell, pond, river, canal, mixed }

extension WaterSourceX on WaterSource {
  String get bangla {
    switch (this) {
      case WaterSource.rainwater:
        return 'বৃষ্টির পানি';
      case WaterSource.tubewell:
        return 'নলকূপ';
      case WaterSource.pond:
        return 'পুকুর';
      case WaterSource.river:
        return 'নদী';
      case WaterSource.canal:
        return 'খাল/ক্যানাল';
      case WaterSource.mixed:
        return 'একাধিক উৎস';
    }
  }

  String get key => name;
}

class Farm {
  const Farm({
    required this.id,
    required this.name,
    required this.location,
    required this.sizeAcres,
    required this.soilType,
    this.notes,
    this.createdAt,
    this.ownerName,
    this.landOwnership = LandOwnership.owned,
    this.waterSource = WaterSource.rainwater,
    this.lastSoilTestDate,
    this.nextSoilTestDate,
    this.photoUrl,
  });

  final String id;
  final String name;
  final String location;
  final double sizeAcres;
  final SoilType soilType;
  final String? notes;
  final DateTime? createdAt;

  // Personal-farm-profile fields (new in v2). All optional / defaulted so
  // older serialized data keeps working without a forced migration.
  final String? ownerName;
  final LandOwnership landOwnership;
  final WaterSource waterSource;
  final DateTime? lastSoilTestDate;

  /// If null, the UI computes a default = lastSoilTest + 1 year.
  final DateTime? nextSoilTestDate;

  /// Public image URL of the farmer's field photo. Stored on the
  /// Farm doc so every device signed in with the same verified phone
  /// loads the same picture. Optional - missing photos render a fallback
  /// gradient on the dashboard and detail screens.
  final String? photoUrl;

  /// Resolved "next soil test" date — falls back to one year after
  /// [lastSoilTestDate] when [nextSoilTestDate] is not explicitly set.
  DateTime? get effectiveNextSoilTestDate {
    if (nextSoilTestDate != null) return nextSoilTestDate;
    if (lastSoilTestDate != null) {
      return DateTime(
        lastSoilTestDate!.year + 1,
        lastSoilTestDate!.month,
        lastSoilTestDate!.day,
      );
    }
    return null;
  }

  Farm copyWith({
    String? name,
    String? location,
    double? sizeAcres,
    SoilType? soilType,
    String? notes,
    String? ownerName,
    LandOwnership? landOwnership,
    WaterSource? waterSource,
    DateTime? lastSoilTestDate,
    DateTime? nextSoilTestDate,
    bool clearNextSoilTestDate = false,
    bool clearLastSoilTestDate = false,
    String? photoUrl,
    bool clearPhotoUrl = false,
  }) {
    return Farm(
      id: id,
      name: name ?? this.name,
      location: location ?? this.location,
      sizeAcres: sizeAcres ?? this.sizeAcres,
      soilType: soilType ?? this.soilType,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      ownerName: ownerName ?? this.ownerName,
      landOwnership: landOwnership ?? this.landOwnership,
      waterSource: waterSource ?? this.waterSource,
      lastSoilTestDate: clearLastSoilTestDate
          ? null
          : (lastSoilTestDate ?? this.lastSoilTestDate),
      nextSoilTestDate: clearNextSoilTestDate
          ? null
          : (nextSoilTestDate ?? this.nextSoilTestDate),
      photoUrl: clearPhotoUrl ? null : (photoUrl ?? this.photoUrl),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'location': location,
    'sizeAcres': sizeAcres,
    'soilType': soilType.key,
    'notes': notes,
    'createdAt': createdAt?.toIso8601String(),
    'ownerName': ownerName,
    'landOwnership': landOwnership.key,
    'waterSource': waterSource.key,
    'lastSoilTestDate': lastSoilTestDate?.toIso8601String(),
    'nextSoilTestDate': nextSoilTestDate?.toIso8601String(),
    'photoUrl': photoUrl,
  };

  factory Farm.fromJson(Map<String, dynamic> json) => Farm(
    id: json['id'] as String,
    name: json['name'] as String,
    location: json['location'] as String,
    sizeAcres: (json['sizeAcres'] as num).toDouble(),
    soilType: SoilType.values.firstWhere(
      (e) => e.key == (json['soilType'] as String? ?? 'unknown'),
      orElse: () => SoilType.unknown,
    ),
    notes: json['notes'] as String?,
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : null,
    ownerName: json['ownerName'] as String?,
    landOwnership: LandOwnership.values.firstWhere(
      (e) => e.key == (json['landOwnership'] as String? ?? 'owned'),
      orElse: () => LandOwnership.owned,
    ),
    waterSource: WaterSource.values.firstWhere(
      (e) => e.key == (json['waterSource'] as String? ?? 'rainwater'),
      orElse: () => WaterSource.rainwater,
    ),
    lastSoilTestDate: json['lastSoilTestDate'] != null
        ? DateTime.parse(json['lastSoilTestDate'] as String)
        : null,
    nextSoilTestDate: json['nextSoilTestDate'] != null
        ? DateTime.parse(json['nextSoilTestDate'] as String)
        : null,
    photoUrl: json['photoUrl'] as String?,
  );
}

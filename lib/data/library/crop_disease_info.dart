import 'package:flutter/foundation.dart';

import '../models/disease.dart';

/// Advisory copy for one class of a crop disease model, keyed (in each
/// crop's map) by the exact label the model returns.
///
/// Pesticides are named by active ingredient (group), not brand, and without
/// doses — the farmer should follow the product label and the local
/// agriculture officer. Content follows common BRRI / BARI / DAE field
/// guidance and should be reviewed by an agronomist before release.
@immutable
class CropDiseaseInfo {
  const CropDiseaseInfo({
    required this.nameBn,
    required this.nameEn,
    required this.severity,
    required this.symptoms,
    required this.causes,
    required this.management,
    required this.fertilizer,
    required this.prevention,
    this.isPest = false,
    this.needsExpertCheck = false,
  });

  final String nameBn;
  final String nameEn;
  final Severity severity;
  final List<String> symptoms;
  final List<String> causes;
  final List<String> management;
  final List<String> fertilizer;
  final List<String> prevention;

  /// Insect / mite damage rather than a disease (changes the wording in the UI).
  final bool isPest;

  /// Classes the model confuses most often (see the test confusion matrix).
  final bool needsExpertCheck;

  String get displayName => '$nameBn ($nameEn)';
}

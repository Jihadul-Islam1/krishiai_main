import 'package:flutter/foundation.dart';

/// One class score from a disease model, e.g. `late_blight` → 0.82.
@immutable
class LabelScore {
  const LabelScore(this.label, this.score, {this.nameBn});

  final String label;
  final double score;

  /// Bangla name sent by the server; used when the app has no advisory
  /// entry for [label].
  final String? nameBn;
}

/// Ranked (highest first) scores from the on-device rice model or the
/// online server.
@immutable
class ScanPrediction {
  const ScanPrediction(this.ranked, {this.isConfident, this.isProbable});

  final List<LabelScore> ranked;

  /// The server's own verdict, tuned for its model. Null for on-device
  /// results, where the app applies its own thresholds.
  final bool? isConfident;
  final bool? isProbable;

  LabelScore get top => ranked.first;
}

/// Labels a model uses for "this photo isn't a leaf of the chosen crop".
const notLeafLabels = {'not_rice', 'not_leaf'};

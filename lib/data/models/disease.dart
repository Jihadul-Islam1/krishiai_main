import 'package:flutter/foundation.dart';

enum Severity { low, medium, high }

extension SeverityX on Severity {
  String get bangla {
    switch (this) {
      case Severity.low:
        return 'হালকা';
      case Severity.medium:
        return 'মাঝারি';
      case Severity.high:
        return 'গুরুতর';
    }
  }

  String get key => name;
}

@immutable
class Disease {
  const Disease({
    required this.id,
    required this.name,
    required this.cropName,
    required this.category,
    required this.symptoms,
    required this.causes,
    required this.prevention,
    required this.management,
    this.imageUrl,
    this.severity = Severity.medium,
  });

  final String id;
  final String name;
  final String cropName;
  final String category;
  final List<String> symptoms;
  final List<String> causes;
  final List<String> prevention;
  final List<String> management;
  final String? imageUrl;
  final Severity severity;
}

import 'package:flutter/foundation.dart';

enum NotificationKind { cropCare, weather, pest, harvest, expense, system }

extension NotificationKindX on NotificationKind {
  String get bangla {
    switch (this) {
      case NotificationKind.cropCare:
        return 'ফসলের যত্ন';
      case NotificationKind.weather:
        return 'আবহাওয়া';
      case NotificationKind.pest:
        return 'কীটপতঙ্গ';
      case NotificationKind.harvest:
        return 'সংগ্রহ';
      case NotificationKind.expense:
        return 'খরচ';
      case NotificationKind.system:
        return 'সিস্টেম';
    }
  }

  String get key => name;
}

@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.kind,
    required this.createdAt,
    this.isRead = false,
    this.relatedId,
  });

  final String id;
  final String title;
  final String message;
  final NotificationKind kind;
  final DateTime createdAt;
  final bool isRead;
  final String? relatedId;

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      message: message,
      kind: kind,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      relatedId: relatedId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'kind': kind.key,
    'createdAt': createdAt.toIso8601String(),
    'isRead': isRead,
    'relatedId': relatedId,
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        title: json['title'] as String,
        message: json['message'] as String,
        kind: NotificationKind.values.firstWhere(
          (e) => e.key == (json['kind'] as String? ?? 'system'),
          orElse: () => NotificationKind.system,
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
        isRead: json['isRead'] as bool? ?? false,
        relatedId: json['relatedId'] as String?,
      );
}

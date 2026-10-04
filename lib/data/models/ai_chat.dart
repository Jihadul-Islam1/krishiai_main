import 'package:flutter/foundation.dart';

enum AIMessageRole { user, assistant, system }

extension AIMessageRoleX on AIMessageRole {
  String get key => name;
}

@immutable
class AIMessage {
  const AIMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.attachmentPath,
    this.contextCropId,
  });

  final String id;
  final AIMessageRole role;
  final String content;
  final DateTime createdAt;
  final String? attachmentPath;
  final String? contextCropId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role.key,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'attachmentPath': attachmentPath,
    'contextCropId': contextCropId,
  };

  factory AIMessage.fromJson(Map<String, dynamic> json) => AIMessage(
    id: json['id'] as String,
    role: AIMessageRole.values.firstWhere(
      (e) => e.key == (json['role'] as String? ?? 'user'),
      orElse: () => AIMessageRole.user,
    ),
    content: json['content'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    attachmentPath: json['attachmentPath'] as String?,
    contextCropId: json['contextCropId'] as String?,
  );
}

@immutable
class AIConversation {
  const AIConversation({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final List<AIMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  AIConversation copyWith({
    String? title,
    List<AIMessage>? messages,
    DateTime? updatedAt,
  }) {
    return AIConversation(
      id: id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'messages': messages.map((m) => m.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory AIConversation.fromJson(Map<String, dynamic> json) => AIConversation(
    id: json['id'] as String,
    title: json['title'] as String? ?? 'নতুন কথোপকথন',
    messages: (json['messages'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AIMessage.fromJson)
        .toList(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(
      (json['updatedAt'] as String?) ?? (json['createdAt'] as String),
    ),
  );
}

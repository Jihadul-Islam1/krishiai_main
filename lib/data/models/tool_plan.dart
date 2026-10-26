/// A saved irrigation / fertilizer plan (`users/{phone}/tool_plans/{id}`).
class ToolPlan {
  const ToolPlan({
    required this.id,
    required this.type,
    required this.title,
    required this.summary,
    required this.data,
    required this.savedAt,
  });

  static const irrigation = 'irrigation';
  static const fertilizer = 'fertilizer';

  final String id;
  final String type;
  final String title;
  final String summary;
  final Map<String, dynamic> data;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'summary': summary,
    'data': data,
    'savedAt': savedAt.toIso8601String(),
  };

  factory ToolPlan.fromJson(Map<String, dynamic> json) => ToolPlan(
    id: json['id'] as String? ?? '',
    type: json['type'] as String? ?? '',
    title: json['title'] as String? ?? '',
    summary: json['summary'] as String? ?? '',
    data: Map<String, dynamic>.from(json['data'] as Map? ?? const {}),
    savedAt:
        DateTime.tryParse(json['savedAt'] as String? ?? '') ?? DateTime.now(),
  );
}

import 'package:flutter/foundation.dart';

enum ExpenseCategory {
  seed,
  fertilizer,
  labor,
  irrigation,
  pesticide,
  transport,
  equipment,
  other,
}

extension ExpenseCategoryX on ExpenseCategory {
  String get bangla {
    switch (this) {
      case ExpenseCategory.seed:
        return 'বীজ';
      case ExpenseCategory.fertilizer:
        return 'সার';
      case ExpenseCategory.labor:
        return 'শ্রম';
      case ExpenseCategory.irrigation:
        return 'সেচ';
      case ExpenseCategory.pesticide:
        return 'কীটনাশক';
      case ExpenseCategory.transport:
        return 'পরিবহন';
      case ExpenseCategory.equipment:
        return 'যন্ত্রপাতি';
      case ExpenseCategory.other:
        return 'অন্যান্য';
    }
  }

  String get key => name;
}

@immutable
class Expense {
  const Expense({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    this.cropId,
    this.notes,
  });

  final String id;
  final String title;
  final ExpenseCategory category;
  final double amount;
  final DateTime date;
  final String? cropId;
  final String? notes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category.key,
    'amount': amount,
    'date': date.toIso8601String(),
    'cropId': cropId,
    'notes': notes,
  };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
    id: json['id'] as String,
    title: json['title'] as String,
    category: ExpenseCategory.values.firstWhere(
      (e) => e.key == (json['category'] as String? ?? 'other'),
      orElse: () => ExpenseCategory.other,
    ),
    amount: (json['amount'] as num).toDouble(),
    date: DateTime.parse(json['date'] as String),
    cropId: json['cropId'] as String?,
    notes: json['notes'] as String?,
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/states.dart';
import '../../../data/models/expense.dart';
import '../../providers/app_providers.dart';

/// Tracks day-to-day farm spend (seed, fertilizer, labor, etc.) saved
/// locally on-device. Includes a monthly summary header, a per-category
/// breakdown card, a list of recent expenses, and a modal sheet for
/// adding a new expense in Bangla.
class ExpenseTrackerScreen extends ConsumerWidget {
  const ExpenseTrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(expensesProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'খরচের হিসাব',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            tooltip: 'রিফ্রেশ',
            icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
            onPressed: () => ref.invalidate(expensesProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSheet(context, ref),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('নতুন খরচ'),
      ),
      body: async.when(
        loading: () => const LoadingState(message: 'খরচ লোড হচ্ছে...'),
        error: (e, _) => ErrorStateView(
          message: e.toString(),
          onRetry: () => ref.invalidate(expensesProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'কোনো খরচ নেই',
              message: 'আজকের প্রথম খরচ যোগ করুন এবং আপনার হিসাব\nশুরু করুন।',
              actionLabel: 'নতুন খরচ যোগ করুন',
              onAction: () => _openAddSheet(context, ref),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(expensesProvider),
            child: _Body(expenses: list),
          );
        },
      ),
    );
  }

  void _openAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _AddExpenseSheet(onSaved: () {
        ref.invalidate(expensesProvider);
      }),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.expenses});
  final List<Expense> expenses;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final thisMonth = expenses
        .where(
          (e) => e.date.year == now.year && e.date.month == now.month,
        )
        .toList();
    final totalThisMonth = thisMonth.fold<double>(0, (a, b) => a + b.amount);

    // Per-category totals for the current month.
    final byCategory = <ExpenseCategory, double>{};
    for (final e in thisMonth) {
      byCategory.update(e.category, (v) => v + e.amount,
          ifAbsent: () => e.amount);
    }

    final sortedList = [...expenses]
      ..sort((a, b) => b.date.compareTo(a.date));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xxxl * 2 + AppSpacing.lg,
      ),
      children: [
        _SummaryCard(total: totalThisMonth, count: thisMonth.length),
        const SizedBox(height: AppSpacing.md),
        _CategoryBreakdownCard(byCategory: byCategory),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              const Text('সাম্প্রতিক লেনদেন', style: AppTextStyles.h3),
              const Spacer(),
              Text(
                '${expenses.length} টি',
                style: AppTextStyles.bodySecondary,
              ),
            ],
          ),
        ),
        ...sortedList.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ExpenseTile(expense: e),
            )),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.total, required this.count});
  final double total;
  final int count;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'এই মাসে মোট খরচ',
                    style: AppTextStyles.bodySecondary.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    AppNumber.money(total),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '$count টি লেনদেন',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBreakdownCard extends StatelessWidget {
  const _CategoryBreakdownCard({required this.byCategory});
  final Map<ExpenseCategory, double> byCategory;

  @override
  Widget build(BuildContext context) {
    if (byCategory.isEmpty) {
      return const SizedBox.shrink();
    }
    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = entries.first.value;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ক্যাটাগরি অনুযায়ী', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.md),
          ...entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _CategoryRow(
                  category: e.key,
                  amount: e.value,
                  share: max == 0 ? 0 : e.value / max,
                ),
              )),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.amount,
    required this.share,
  });
  final ExpenseCategory category;
  final double amount;
  final double share;

  IconData get _icon {
    switch (category) {
      case ExpenseCategory.seed:
        return Icons.eco_outlined;
      case ExpenseCategory.fertilizer:
        return Icons.science_outlined;
      case ExpenseCategory.labor:
        return Icons.groups_outlined;
      case ExpenseCategory.irrigation:
        return Icons.water_drop_outlined;
      case ExpenseCategory.pesticide:
        return Icons.bug_report_outlined;
      case ExpenseCategory.transport:
        return Icons.local_shipping_outlined;
      case ExpenseCategory.equipment:
        return Icons.agriculture_outlined;
      case ExpenseCategory.other:
        return Icons.category_outlined;
    }
  }

  Color get _color {
    final palette = AppColors.chartPalette;
    return palette[category.index % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(_icon, color: _color, size: 20),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      category.bangla,
                      style: AppTextStyles.bodyBold,
                    ),
                  ),
                  Text(AppNumber.money(amount), style: AppTextStyles.bodyBold),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: share.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation(_color),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExpenseTile extends ConsumerWidget {
  const _ExpenseTile({required this.expense});
  final Expense expense;

  IconData get _icon {
    switch (expense.category) {
      case ExpenseCategory.seed:
        return Icons.eco_outlined;
      case ExpenseCategory.fertilizer:
        return Icons.science_outlined;
      case ExpenseCategory.labor:
        return Icons.groups_outlined;
      case ExpenseCategory.irrigation:
        return Icons.water_drop_outlined;
      case ExpenseCategory.pesticide:
        return Icons.bug_report_outlined;
      case ExpenseCategory.transport:
        return Icons.local_shipping_outlined;
      case ExpenseCategory.equipment:
        return Icons.agriculture_outlined;
      case ExpenseCategory.other:
        return Icons.category_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      onTap: () => _showActions(context, ref),
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: AppColors.surface,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(_icon, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.title,
                  style: AppTextStyles.bodyBold,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${expense.category.bangla} • ${AppDate.relativeBangla(expense.date)}',
                  style: AppTextStyles.bodySecondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            AppNumber.money(expense.amount),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _showActions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      expense.title,
                      style: AppTextStyles.h3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    AppNumber.money(expense.amount),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: AppColors.danger),
              title: const Text(
                'মুছে ফেলুন',
                style: TextStyle(color: AppColors.danger),
              ),
              onTap: () async {
                Navigator.pop(context);
                final repo = await ref.read(expenseRepoProvider.future);
                await repo.delete(expense.id);
                ref.invalidate(expensesProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('খরচ মুছে ফেলা হয়েছে')),
                  );
                }
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _AddExpenseSheet extends ConsumerStatefulWidget {
  const _AddExpenseSheet({required this.onSaved});
  final VoidCallback onSaved;

  @override
  ConsumerState<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<_AddExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  ExpenseCategory _category = ExpenseCategory.seed;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = await ref.read(expenseRepoProvider.future);
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final expense = Expense(
      id: 'exp_${DateTime.now().millisecondsSinceEpoch}',
      title: _titleController.text.trim(),
      category: _category,
      amount: amount,
      date: _date,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );
    await repo.add(expense);
    if (!mounted) return;
    widget.onSaved();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('খরচ যোগ করা হয়েছে')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Icon(
                        Icons.add_circle_outline,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('নতুন খরচ', style: AppTextStyles.h3),
                          SizedBox(height: 2),
                          Text(
                            'বিবরণ পূরণ করুন',
                            style: AppTextStyles.bodySecondary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                AppTextField(
                  label: 'শিরোনাম',
                  hint: 'যেমন: ধানের বীজ কিনেছি',
                  controller: _titleController,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'শিরোনাম দিন' : null,
                  prefixIcon: Icons.title_outlined,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'পরিমাণ (৳)',
                  hint: '0',
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').trim());
                    if (n == null || n <= 0) return 'সঠিক পরিমাণ দিন';
                    return null;
                  },
                  prefixIcon: Icons.attach_money_outlined,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('ক্যাটাগরি', style: AppTextStyles.bodyBold),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ...ExpenseCategory.values.map((c) => Padding(
                            padding:
                                const EdgeInsets.only(right: AppSpacing.sm),
                            child: AppChip(
                              label: c.bangla,
                              selected: _category == c,
                              onTap: () => setState(() => _category = c),
                            ),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('তারিখ', style: AppTextStyles.bodyBold),
                const SizedBox(height: AppSpacing.sm),
                InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            AppDate.full(_date),
                            style: AppTextStyles.body,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'নোট (ঐচ্ছিক)',
                  hint: 'অতিরিক্ত কোনো তথ্য...',
                  controller: _notesController,
                  maxLines: 3,
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'সংরক্ষণ করুন',
                  icon: Icons.check,
                  loading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
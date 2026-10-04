import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/states.dart';
import '../../../data/models/expense.dart';
import '../../providers/app_providers.dart';

/// Analytics dashboard. Derived from expensesProvider.
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('বিশ্লেষণ'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(expensesProvider),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'রিফ্রেশ',
          ),
        ],
      ),
      body: expensesAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorStateView(
          message: 'তথ্য লোড করা যায়নি',
          onRetry: () => ref.invalidate(expensesProvider),
        ),
        data: (expenses) => expenses.isEmpty
            ? const _EmptyAnalytics()
            : _Body(expenses: expenses),
      ),
    );
  }
}

class _EmptyAnalytics extends StatelessWidget {
  const _EmptyAnalytics();
  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.insights_rounded,
      title: 'কোনো তথ্য নেই',
      message: 'খরচ যোগ করলে এখানে বিশ্লেষণ দেখতে পাবেন।',
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.expenses});
  final List<Expense> expenses;

  @override
  Widget build(BuildContext context) {
    final total = expenses.fold<double>(0, (s, e) => s + e.amount);
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final thisMonth = expenses
        .where((e) => !e.date.isBefore(monthStart))
        .fold<double>(0, (s, e) => s + e.amount);
    final monthly = _bucketByMonth(expenses, now);
    final byCategory = _bucketByCategory(expenses);
    final recent = [...expenses]..sort((a, b) => b.date.compareTo(a.date));
    final recent5 = recent.take(5).toList();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _KpiGrid(total: total, thisMonth: thisMonth),
        const SizedBox(height: AppSpacing.md),
        _TrendCard(monthly: monthly),
        const SizedBox(height: AppSpacing.md),
        _CategoryCard(byCategory: byCategory, total: total),
        const SizedBox(height: AppSpacing.md),
        _RecentCard(expenses: recent5),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  static List<_MonthBucket> _bucketByMonth(List<Expense> list, DateTime now) {
    final buckets = <int, double>{};
    for (var i = 5; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      buckets[m.year * 12 + m.month] = 0;
    }
    for (final e in list) {
      final key = e.date.year * 12 + e.date.month;
      if (buckets.containsKey(key)) buckets[key] = (buckets[key] ?? 0) + e.amount;
    }
    final out = <_MonthBucket>[];
    for (var i = 5; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      out.add(_MonthBucket(
        label: _monthLabel(m.month),
        value: buckets[m.year * 12 + m.month] ?? 0,
      ));
    }
    return out;
  }

  static Map<ExpenseCategory, double> _bucketByCategory(List<Expense> list) {
    final map = <ExpenseCategory, double>{};
    for (final e in list) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }

  static const _bn = [
    'জানু', 'ফেব্রু', 'মার্চ', 'এপ্রি', 'মে', 'জুন',
    'জুলা', 'আগ', 'সেপ্ট', 'অক্টো', 'নভে', 'ডিসে',
  ];
  static String _monthLabel(int m) => _bn[(m - 1).clamp(0, 11)];
}

class _MonthBucket {
  const _MonthBucket({required this.label, required this.value});
  final String label;
  final double value;
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.total, required this.thisMonth});
  final double total;
  final double thisMonth;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _KpiTile(
            label: 'মোট খরচ',
            value: AppNumber.money(total),
            icon: Icons.payments_rounded,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _KpiTile(
            label: 'এই মাসে',
            value: AppNumber.money(thisMonth),
            icon: Icons.calendar_today_rounded,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(label,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value,
              style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.monthly});
  final List<_MonthBucket> monthly;

  @override
  Widget build(BuildContext context) {
    final maxV = monthly.fold<double>(0, (m, b) => b.value > m ? b.value : m);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text('গত ৬ মাসের খরচ', style: AppTextStyles.title),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 160,
            child: CustomPaint(
              size: Size.infinite,
              painter: _BarChartPainter(
                values: monthly.map((b) => b.value).toList(),
                labels: monthly.map((b) => b.label).toList(),
                maxValue: maxV <= 0 ? 1 : maxV,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({
    required this.values,
    required this.labels,
    required this.maxValue,
  });
  final List<double> values;
  final List<String> labels;
  final double maxValue;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const labelH = 18.0;
    final chartH = size.height - labelH;
    final n = values.length;
    final gap = 8.0;
    final barW = (size.width - gap * (n - 1)) / n;
    final paint = Paint()..color = AppColors.primary;
    final paintTip = Paint()..color = AppColors.primaryDark;
    final textStyle = TextStyle(
      color: AppColors.textSecondary,
      fontSize: 10,
    );
    for (var i = 0; i < n; i++) {
      final v = values[i].clamp(0.0, maxValue);
      final h = (v / maxValue) * (chartH - 16);
      final x = i * (barW + gap);
      final y = chartH - h;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, y, barW, h),
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
      );
      canvas.drawRRect(
        rect,
        (v == maxValue && v > 0) ? paintTip : paint,
      );
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + (barW - tp.width) / 2, chartH + 2));
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) =>
      old.values != values || old.maxValue != maxValue;
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.byCategory, required this.total});
  final Map<ExpenseCategory, double> byCategory;
  final double total;

  @override
  Widget build(BuildContext context) {
    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_rounded, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Text('ক্যাটাগরি অনুযায়ী', style: AppTextStyles.title),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (entries.isEmpty)
            Text('কোনো তথ্য নেই', style: AppTextStyles.bodySecondary),
          for (var i = 0; i < entries.length; i++)
            Padding(
              padding: EdgeInsets.only(
                  bottom: i == entries.length - 1 ? 0 : AppSpacing.sm),
              child: _CategoryRow(
                category: entries[i].key,
                amount: entries[i].value,
                total: total,
                paletteIndex: i,
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.amount,
    required this.total,
    required this.paletteIndex,
  });
  final ExpenseCategory category;
  final double amount;
  final double total;
  final int paletteIndex;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.chartPalette;
    final color = palette[paletteIndex % palette.length];
    final pct = total <= 0 ? 0.0 : (amount / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(category.bangla, style: AppTextStyles.body),
            ),
            Text(AppNumber.money(amount),
                style: AppTextStyles.bodyBold
                    .copyWith(color: AppColors.textPrimary)),
            const SizedBox(width: AppSpacing.sm),
            Text(AppNumber.percent(pct),
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: AppColors.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.expenses});
  final List<Expense> expenses;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: AppColors.info),
              const SizedBox(width: AppSpacing.sm),
              Text('সাম্প্রতিক লেনদেন', style: AppTextStyles.title),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (expenses.isEmpty)
            Text('কোনো তথ্য নেই', style: AppTextStyles.bodySecondary),
          for (var i = 0; i < expenses.length; i++)
            Padding(
              padding: EdgeInsets.only(
                  bottom: i == expenses.length - 1 ? 0 : AppSpacing.sm),
              child: _RecentRow(expense: expenses[i]),
            ),
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.expense});
  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.chartPalette;
    final color = palette[expense.category.index % palette.length];
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_iconFor(expense.category), color: color, size: 18),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(expense.title,
                  style: AppTextStyles.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(
                  '${expense.category.bangla} • ${AppDate.relativeBangla(expense.date)}',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(AppNumber.money(expense.amount),
            style: AppTextStyles.bodyBold
                .copyWith(color: AppColors.textPrimary)),
      ],
    );
  }

  IconData _iconFor(ExpenseCategory c) {
    switch (c) {
      case ExpenseCategory.seed:
        return Icons.grass_rounded;
      case ExpenseCategory.fertilizer:
        return Icons.science_rounded;
      case ExpenseCategory.labor:
        return Icons.engineering_rounded;
      case ExpenseCategory.irrigation:
        return Icons.water_drop_rounded;
      case ExpenseCategory.pesticide:
        return Icons.bug_report_rounded;
      case ExpenseCategory.transport:
        return Icons.local_shipping_rounded;
      case ExpenseCategory.equipment:
        return Icons.handyman_rounded;
      case ExpenseCategory.other:
        return Icons.more_horiz_rounded;
    }
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/states.dart';
import '../../../data/models/crop.dart';
import '../../../data/models/expense.dart';
import '../../../data/models/farm.dart';
import '../../providers/app_providers.dart';

class CropDetailScreen extends ConsumerWidget {
  const CropDetailScreen({super.key, required this.cropId});

  final String cropId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cropsAsync = ref.watch(cropsProvider);
    final farmsAsync = ref.watch(farmsProvider);
    final expensesAsync = ref.watch(expensesProvider);

    return cropsAsync.when(
      loading: () => const Scaffold(body: LoadingState()),
      error: (e, _) => Scaffold(
        body: ErrorStateView(
          message: e.toString(),
          onRetry: () => ref.invalidate(cropsProvider),
        ),
      ),
      data: (crops) {
        Crop? crop;
        try {
          crop = crops.firstWhere((c) => c.id == cropId);
        } catch (_) {
          crop = null;
        }
        if (crop == null) {
          return Scaffold(
            appBar: AppBar(title: const Text(AppStrings.crop)),
            body: EmptyState(
              icon: Icons.error_outline,
              title: AppStrings.cropNotFound,
              actionLabel: AppStrings.back,
              onAction: () => context.pop(),
            ),
          );
        }
        final farm = farmsAsync.maybeWhen(
          data: (farms) => farms.firstWhere(
            (f) => f.id == crop!.farmId,
            orElse: () => Farm(
              id: crop!.farmId,
              name: AppStrings.unknownFarm,
              location: '',
              sizeAcres: 0,
              soilType: SoilType.unknown,
            ),
          ),
          orElse: () => null,
        );
        final cropExpenses = expensesAsync.maybeWhen(
          data: (all) => all.where((e) => e.cropId == crop!.id).toList(),
          orElse: () => <Expense>[],
        );
        return _Detail(
          crop: crop,
          farm: farm,
          expenses: cropExpenses,
          onDelete: () => _confirmDelete(context, ref, crop!),
        );
      },
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Crop crop) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(AppStrings.deleteCrop),
        content: Text('${AppStrings.deleteCropConfirm} ${crop.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
    if (ok == true) {
      final repo = await ref.read(cropRepoProvider.future);
      await repo.delete(crop.id);
      ref.invalidate(cropsProvider);
      if (context.mounted) context.pop();
    }
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.crop,
    required this.farm,
    required this.expenses,
    required this.onDelete,
  });
  final Crop crop;
  final Farm? farm;
  final List<Expense> expenses;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM yyyy');
    final totalExpense = expenses.fold<double>(0, (s, e) => s + e.amount);
    return Scaffold(
      appBar: AppBar(
        title: Text(crop.name),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.12),
                      child: const Icon(Icons.eco,
                          color: AppColors.primary),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(crop.name,
                              style: Theme.of(context).textTheme.titleLarge),
                          Text('${crop.variety} • ${farm?.name ?? "-"}',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(
                        icon: Icons.calendar_today,
                        label: AppStrings.planted,
                        value: df.format(crop.plantingDate)),
                    _InfoChip(
                        icon: Icons.event,
                        label: AppStrings.expectedHarvest,
                        value: df.format(crop.expectedHarvestDate)),
                    _InfoChip(
                        icon: Icons.straighten,
                        label: AppStrings.area,
                        value:
                            '${crop.landSizeAcres.toStringAsFixed(1)} ${AppStrings.acres}'),
                    _InfoChip(
                        icon: Icons.water_drop,
                        label: AppStrings.irrigation,
                        value: crop.irrigation.bangla),
                    _InfoChip(
                        icon: Icons.grass,
                        label: AppStrings.soil,
                        value: crop.soilType.bangla),
                    _InfoChip(
                        icon: Icons.timeline,
                        label: AppStrings.stage,
                        value: crop.stage.bangla),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(AppStrings.timeline,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          _Timeline(crop: crop, now: DateTime.now()),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(AppStrings.expenses,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              Text(
                  'মোট: ৳ ${totalExpense.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (expenses.isEmpty)
            const EmptyState(
              icon: Icons.receipt_long,
              title: AppStrings.noExpenses,
              message: AppStrings.addExpenseHint,
            )
          else
            for (final e in expenses) ...[
              _ExpenseTile(expense: e),
              const SizedBox(height: AppSpacing.sm),
            ],
          const SizedBox(height: AppSpacing.lg),
          if (crop.notes != null && crop.notes!.isNotEmpty) ...[
            Text(AppStrings.notes,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            AppCard(child: Text(crop.notes!)),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text('$label: ', style: Theme.of(context).textTheme.bodySmall),
          Text(value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  )),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.crop, required this.now});
  final Crop crop;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final stages = CropStage.values;
    final currentIdx = stages.indexOf(crop.stage);
    final totalDays =
        crop.expectedHarvestDate.difference(crop.plantingDate).inDays;
    final elapsedDays = now.difference(crop.plantingDate).inDays;
    final progressPct =
        totalDays <= 0 ? 0.0 : (elapsedDays / totalDays).clamp(0.0, 1.0);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: progressPct,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            color: AppColors.primary,
            minHeight: 8,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${AppDate.short(crop.plantingDate)}  →  ${AppDate.short(crop.expectedHarvestDate)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < stages.length; i++)
            _StageRow(
              label: stages[i].bangla,
              done: i <= currentIdx,
              isCurrent: i == currentIdx,
            ),
        ],
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.label,
    required this.done,
    required this.isCurrent,
  });
  final String label;
  final bool done;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final color = done ? AppColors.primary : Colors.black26;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isCurrent
                ? Icons.radio_button_checked
                : (done ? Icons.check_circle : Icons.radio_button_unchecked),
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: done ? Colors.black87 : Colors.black54,
                ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.expense});
  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM');
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.accent.withValues(alpha: 0.12),
            child: const Icon(Icons.receipt_long,
                size: 18, color: AppColors.accent),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(expense.title,
                    style: Theme.of(context).textTheme.titleSmall),
                Text(
                  '${expense.category.bangla} • ${df.format(expense.date)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text('৳ ${expense.amount.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
        ],
      ),
    );
  }
}
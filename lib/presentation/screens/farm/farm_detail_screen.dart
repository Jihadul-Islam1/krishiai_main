import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/icon_badge.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/states.dart';
import '../../../data/models/crop.dart';
import '../../../data/models/expense.dart';
import '../../../data/models/farm.dart';
import '../../providers/app_providers.dart';

/// Per-farm personal-farmer profile: owner info, soil / water / ownership
/// details, soil-test reminder, list of crops on this farm, and a quick
/// expense summary. Reached by tapping a farm card on /farm.
class FarmDetailScreen extends ConsumerWidget {
  const FarmDetailScreen({super.key, required this.farmId});

  final String farmId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmsAsync = ref.watch(farmsProvider);
    final cropsAsync = ref.watch(cropsProvider);
    final expensesAsync = ref.watch(expensesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.farmProfile),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: farmsAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorStateView(
          message: 'খামার লোড করা যায়নি: \$e',
          onRetry: () => ref.invalidate(farmsProvider),
        ),
        data: (farms) {
          final farm = farms.where((f) => f.id == farmId).firstOrNull;
          if (farm == null) {
            return const _NotFoundBody();
          }

          final cropsHere = (cropsAsync.valueOrNull ?? const <Crop>[])
              .where((c) => c.farmId == farmId)
              .toList();
          final cropIds = cropsHere.map((c) => c.id).toSet();
          final expensesHere = (expensesAsync.valueOrNull ?? const <Expense>[])
              .where((e) => e.cropId != null && cropIds.contains(e.cropId))
              .toList();

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _Hero(farm: farm, cropsCount: cropsHere.length),
              const SizedBox(height: AppSpacing.lg),
              _SoilTestCard(farm: farm),
              const SizedBox(height: AppSpacing.lg),
              SectionHeader(
                title: AppStrings.farmCropsHere,
                actionLabel: AppStrings.addCropToFarm,
                onAction: () => context.push(
                  '/farm/add-crop',
                  extra: <String, dynamic>{'farmId': farm.id},
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (cropsHere.isEmpty)
                const _EmptyCrops()
              else
                ...cropsHere.map((c) => Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: _CropTile(crop: c),
                    )),
              const SizedBox(height: AppSpacing.lg),
              if (expensesHere.isNotEmpty)
                _ExpenseSummary(expenses: expensesHere),
              const SizedBox(height: AppSpacing.lg),
              if (farm.notes != null && farm.notes!.trim().isNotEmpty)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppStrings.farmNotes,
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: AppSpacing.sm),
                      Text(farm.notes!,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.farm, required this.cropsCount});
  final Farm farm;
  final int cropsCount;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: AppColors.primary,
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(
                icon: Icons.agriculture,
                tint: Colors.white24,
                color: Colors.white,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(farm.name,
                        style: tt.headlineSmall?.copyWith(color: Colors.white)),
                    Text(farm.location,
                        style: tt.bodyMedium?.copyWith(color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _Pill(text: '\${farm.sizeAcres.toStringAsFixed(1)} \${AppStrings.acres}'),
              _Pill(text: farm.soilType.bangla),
              _Pill(text: '\$cropsCount \${AppStrings.crop}'),
            ],
          ),
          if (farm.ownerName != null && farm.ownerName!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text('\${AppStrings.farmOwnerName}: \${farm.ownerName}',
                style: tt.bodyMedium?.copyWith(color: Colors.white)),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }
}

class _SoilTestCard extends StatelessWidget {
  const _SoilTestCard({required this.farm});
  final Farm farm;

  @override
  Widget build(BuildContext context) {
    final last = farm.lastSoilTestDate;
    final next = farm.effectiveNextSoilTestDate;
    final tt = Theme.of(context).textTheme;

    String statusText;
    Color statusColor;
    IconData statusIcon;
    if (last == null) {
      statusText = AppStrings.farmSoilTestNone;
      statusColor = AppColors.textSecondary;
      statusIcon = Icons.help_outline;
    } else {
      final today = DateTime.now();
      final today0 = DateTime(today.year, today.month, today.day);
      final daysLeft = next == null
          ? 9999
          : next.difference(today0).inDays;
      if (next == null) {
        statusText = AppStrings.farmSoilTestNone;
        statusColor = AppColors.textSecondary;
        statusIcon = Icons.help_outline;
      } else if (daysLeft < 0) {
        statusText = '\${AppStrings.farmSoilTestOverdue} (\${-daysLeft} দিন আগে)';
        statusColor = AppColors.danger;
        statusIcon = Icons.warning_amber_rounded;
      } else if (daysLeft <= 30) {
        statusText = '\${AppStrings.farmSoilTestDue} (\$daysLeft দিন বাকি)';
        statusColor = AppColors.warning;
        statusIcon = Icons.schedule;
      } else {
        statusText = '\${AppStrings.farmNextSoilTest}: \${AppDate.full(next)} (\$daysLeft দিন বাকি)';
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_outline;
      }
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor),
              const SizedBox(width: AppSpacing.sm),
              Text(AppStrings.farmLastSoilTest, style: tt.titleSmall),
              const Spacer(),
              Text(
                last == null ? AppStrings.notSet : AppDate.full(last),
                style: tt.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(statusText, style: TextStyle(color: statusColor)),
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              _ProfilePair(
                icon: Icons.terrain,
                label: AppStrings.soil,
                value: farm.soilType.bangla,
              ),
              _ProfilePair(
                icon: Icons.water_drop_outlined,
                label: AppStrings.farmWaterSource,
                value: farm.waterSource.bangla,
              ),
              _ProfilePair(
                icon: Icons.landscape_outlined,
                label: AppStrings.farmLandOwnership,
                value: farm.landOwnership.bangla,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfilePair extends StatelessWidget {
  const _ProfilePair(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: tt.labelSmall?.copyWith(color: AppColors.textSecondary)),
            Text(value, style: tt.bodyMedium),
          ],
        ),
      ],
    );
  }
}

class _CropTile extends StatelessWidget {
  const _CropTile({required this.crop});
  final Crop crop;
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return AppCard(
      onTap: () => context.push('/farm/crop/\${crop.id}'),
      child: Row(
        children: [
          IconBadge(
            icon: Icons.eco_outlined,
            tint: AppColors.primaryLight,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(crop.name, style: tt.titleSmall),
                Text(
                  '\${crop.stage.bangla} • \${crop.landSizeAcres.toStringAsFixed(1)} \${AppStrings.acres}',
                  style: tt.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

class _EmptyCrops extends StatelessWidget {
  const _EmptyCrops();
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.grass_outlined, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(AppStrings.farmNoCropsHere)),
        ],
      ),
    );
  }
}

class _ExpenseSummary extends StatelessWidget {
  const _ExpenseSummary({required this.expenses});
  final List<Expense> expenses;
  @override
  Widget build(BuildContext context) {
    final total = expenses.fold<double>(0, (sum, e) => sum + e.amount);
    final byCat = <ExpenseCategory, double>{};
    for (final e in expenses) {
      byCat[e.category] = (byCat[e.category] ?? 0) + e.amount;
    }
    final entries = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('\${AppStrings.expenses} (এই খামার)',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(AppNumber.money(total),
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          for (final e in entries.take(5))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(child: Text(e.key.bangla)),
                  Text(AppNumber.money(e.value)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NotFoundBody extends StatelessWidget {
  const _NotFoundBody();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text(AppStrings.cropNotFound, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () => context.pop(),
              child: const Text('ফিরে যান'),
            ),
          ],
        ),
      ),
    );
  }
}

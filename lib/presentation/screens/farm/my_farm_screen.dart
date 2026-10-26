import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_divider.dart';
import '../../../core/widgets/icon_badge.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/states.dart';
import '../../../data/models/crop.dart';
import '../../../data/models/farm.dart';
import '../../providers/app_providers.dart';

/// /farm — My Farm dashboard.
class MyFarmScreen extends ConsumerWidget {
  const MyFarmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmsAsync = ref.watch(farmsProvider);
    final cropsAsync = ref.watch(cropsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: farmsAsync.when(
        loading: () => const _LoadingShell(),
        error: (e, _) => ErrorStateView(
          message: e.toString(),
          onRetry: () => ref.invalidate(farmsProvider),
        ),
        data: (farms) {
          final crops = cropsAsync.maybeWhen(
            data: (c) => c,
            orElse: () => <Crop>[],
          );
          // Same layout with or without farms (zero stats, empty list card).
          return _FarmBody(
            farms: farms,
            crops: crops,
            onRefresh: () async {
              ref.invalidate(farmsProvider);
              ref.invalidate(cropsProvider);
            },
          );
        },
      ),
    );
  }
}

class _LoadingShell extends StatelessWidget {
  const _LoadingShell();
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 220,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.weatherCard, AppColors.fieldCard],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('OVERVIEW',
                  style: AppTextStyles.overline
                      .copyWith(color: const Color(0xB3FFFFFF))),
                const SizedBox(height: AppSpacing.xxs),
                Text(AppStrings.tabFarm,
                  style: AppTextStyles.h1.copyWith(color: Colors.white)),
              ],
            ),
          ),
        ),
        const Positioned(
          left: 0, right: 0, bottom: 80,
          child: Center(child: LoadingState(message: AppStrings.farmLoadingHeader)),
        ),
      ],
    );
  }
}

class _FarmBody extends ConsumerStatefulWidget {
  const _FarmBody({
    required this.farms,
    required this.crops,
    required this.onRefresh,
  });
  final List<Farm> farms;
  final List<Crop> crops;
  final Future<void> Function() onRefresh;

  @override
  ConsumerState<_FarmBody> createState() => _FarmBodyState();
}

class _FarmBodyState extends ConsumerState<_FarmBody> {
  _FarmFilter _filter = _FarmFilter.all;

  int _cropsForFarm(String farmId) =>
      widget.crops.where((c) => c.farmId == farmId).length;

  List<Farm> get _filteredFarms {
    switch (_filter) {
      case _FarmFilter.all:
        return widget.farms;
      case _FarmFilter.withCrops:
        return widget.farms
            .where((f) => _cropsForFarm(f.id) > 0)
            .toList(growable: false);
      case _FarmFilter.empty:
        return widget.farms
            .where((f) => _cropsForFarm(f.id) == 0)
            .toList(growable: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalAcres =
        widget.farms.fold<double>(0, (s, f) => s + f.sizeAcres);
    final cropsCount = widget.crops.length;
    final visible = _filteredFarms;
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: _HeroHeader(
              farms: widget.farms.length,
              acres: totalAcres,
              crops: cropsCount,
              onAdd: () => context.push('/farm/add'),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
              child: _FilterChips(
                value: _filter,
                onChanged: (v) => setState(() => _filter = v),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
              child: _QuickActions(onAddCrop: () => context.push('/farm/add-crop')),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, 0),
              child: _HealthStrip(crops: widget.crops),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.huge),
            sliver: SliverList(
              delegate: SliverChildListDelegate.fixed([
                SectionHeader(
                  eyebrow: 'YOUR FIELDS',
                  title: AppStrings.myFarms,
                  subtitle: '${visible.length} ${AppStrings.farms}',
                  actionLabel: AppStrings.add,
                  onAction: () => context.push('/farm/add'),
                ),
                const SizedBox(height: AppSpacing.md),
                if (visible.isEmpty)
                  AppCard(
                    bordered: true,
                    onTap: widget.farms.isEmpty
                        ? () => context.push('/farm/add')
                        : null,
                    child: Row(
                      children: [
                        IconBadge(
                          icon: widget.farms.isEmpty
                              ? Icons.add_location_alt_outlined
                              : Icons.filter_alt_off_rounded,
                          tint: widget.farms.isEmpty
                              ? AppColors.tintGreen
                              : AppColors.tintSlate,
                          color: widget.farms.isEmpty
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            widget.farms.isEmpty
                                ? '${AppStrings.noFarmsYet}। ${AppStrings.addFirstFarm} — এখানে ট্যাপ করুন।'
                                : 'এই ফিল্টারে কোনো খামার নেই।',
                            style: AppTextStyles.bodySecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (final farm in visible) ...[
                    _FarmCard(
                      key: ValueKey('farm-${farm.id}'),
                      farm: farm,
                      cropsCount: _cropsForFarm(farm.id),
                      onTap: () => context.push('/farm/${farm.id}'),
                      onAddCrop: () => context.push(
                        '/farm/add-crop',
                        extra: {'farmId': farm.id},
                      ),
                      onScan: () => context.push('/ai/scan'),
                      onExpense: () => context.push('/expenses'),
                      onDelete: () => _confirmDelete(farm),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Farm farm) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(AppStrings.delete),
        content: Text(
          '"${farm.name}" মুছে ফেলতে চান? এই খামারের ফসল তালিকা থেকেও সরানো হবে।',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              AppStrings.delete,
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final repo = await ref.read(farmRepoProvider.future);
    await repo.delete(farm.id);
    ref.invalidate(farmsProvider);
    ref.invalidate(cropsProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${farm.name}" মুছে ফেলা হয়েছে।')),
    );
  }
}

enum _FarmFilter { all, withCrops, empty }

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.farms,
    required this.acres,
    required this.crops,
    required this.onAdd,
  });
  final int farms;
  final double acres;
  final int crops;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.weatherCard, AppColors.fieldCard],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('OVERVIEW',
                          style: AppTextStyles.overline.copyWith(
                            color: Colors.white.withValues(alpha: 0.7))),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(AppStrings.tabFarm,
                          style: AppTextStyles.h1.copyWith(color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(
                          '${DateFormat('d MMM, EEE').format(DateTime.now())} · সর্বশেষ হালনাগাদ',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.78)),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onAdd,
                      child: const SizedBox(
                        width: 44, height: 44,
                        child: Icon(Icons.add_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _HeroStats(farms: farms, acres: acres, crops: crops),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroStats extends StatelessWidget {
  const _HeroStats({required this.farms, required this.acres, required this.crops});
  final int farms;
  final double acres;
  final int crops;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md, vertical: AppSpacing.md),
      child: Row(
        children: [
          Expanded(child: _HeroStat(icon: Icons.grass_rounded, value: '$farms', label: AppStrings.farms)),
          Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.18)),
          Expanded(child: _HeroStat(icon: Icons.straighten_rounded, value: acres.toStringAsFixed(1), label: AppStrings.acres)),
          Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.18)),
          Expanded(child: _HeroStat(icon: Icons.eco_rounded, value: '$crops', label: AppStrings.crops)),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.circle, size: 8, color: Color(0xFFA7F3D0)),
      const SizedBox(height: 4),
      Text(value, style: AppTextStyles.stat.copyWith(color: const Color(0xFFF0FDF4))),
      const SizedBox(height: 2),
      Text(label,
        style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.78))),
    ]);
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.value, required this.onChanged});
  final _FarmFilter value;
  final ValueChanged<_FarmFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final f in _FarmFilter.values) ...[
            AppChip(
              label: _labelFor(f),
              icon: _iconFor(f),
              selected: value == f,
              onTap: () => onChanged(f),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }

  String _labelFor(_FarmFilter f) {
    switch (f) {
      case _FarmFilter.all: return AppStrings.farmFilterAll;
      case _FarmFilter.withCrops: return AppStrings.farmFilterWithCrops;
      case _FarmFilter.empty: return AppStrings.farmFilterEmpty;
    }
  }

  IconData _iconFor(_FarmFilter f) {
    switch (f) {
      case _FarmFilter.all: return Icons.dashboard_rounded;
      case _FarmFilter.withCrops: return Icons.eco_rounded;
      case _FarmFilter.empty: return Icons.inbox_rounded;
    }
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onAddCrop});
  final VoidCallback onAddCrop;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(AppStrings.farmQuickActionsHeader, style: AppTextStyles.titleLarge),
      const SizedBox(height: 2),
      Text(AppStrings.farmQuickActionsSubtitle, style: AppTextStyles.bodySecondary),
      const SizedBox(height: AppSpacing.md),
      Row(children: [
        Expanded(child: _QuickActionTile(
          icon: Icons.eco_rounded,
          tint: AppColors.tintGreen, color: AppColors.primary,
          title: AppStrings.farmQuickAddCrop,
          subtitle: AppStrings.farmQuickAddCropHint,
          onTap: onAddCrop,
        )),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _QuickActionTile(
          icon: Icons.center_focus_strong_rounded,
          tint: AppColors.tintBlue, color: AppColors.info,
          title: AppStrings.farmQuickCropDoctor,
          subtitle: AppStrings.farmQuickCropDoctorHint,
          onTap: () => context.push('/ai/scan'),
        )),
      ]),
      const SizedBox(height: AppSpacing.md),
      Row(children: [
        Expanded(child: _QuickActionTile(
          icon: Icons.receipt_long_rounded,
          tint: AppColors.tintAmber, color: AppColors.accentDark,
          title: AppStrings.farmQuickExpense,
          subtitle: AppStrings.farmQuickExpenseHint,
          onTap: () => context.push('/expenses'),
        )),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _QuickActionTile(
          icon: Icons.cloud_outlined,
          tint: AppColors.tintViolet, color: const Color(0xFF7C3AED),
          title: AppStrings.farmQuickWeather,
          subtitle: AppStrings.farmQuickWeatherHint,
          onTap: () => context.push('/weather'),
        )),
      ]),
    ]);
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon, required this.tint, required this.color,
    required this.title, required this.subtitle, required this.onTap,
  });
  final IconData icon;
  final Color tint;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      bordered: true,
      borderColor: AppColors.border,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(children: [
        IconBadge(icon: icon, tint: tint, color: color, size: 44, shape: BoxShape.rectangle),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppTextStyles.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(subtitle, style: AppTextStyles.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
        ])),
        const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
      ]),
    );
  }
}

class _HealthStrip extends StatelessWidget {
  const _HealthStrip({required this.crops});
  final List<Crop> crops;

  @override
  Widget build(BuildContext context) {
    if (crops.isEmpty) {
      return AppCard(
        bordered: true,
        child: Row(children: [
          const IconBadge(
            icon: Icons.spa_outlined,
            tint: AppColors.tintGreen,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(AppStrings.farmHealthEmpty, style: AppTextStyles.title),
            const SizedBox(height: 2),
            Text(AppStrings.farmHealthEmptyHint, style: AppTextStyles.bodySecondary),
          ])),
        ]),
      );
    }
    final total = crops.length;
    final planted = crops.where((c) => c.stage == CropStage.planted).length;
    final growing = crops.where((c) =>
        c.stage == CropStage.earlyGrowth ||
        c.stage == CropStage.vegetative ||
        c.stage == CropStage.flowering ||
        c.stage == CropStage.fruiting).length;
    final ready = crops.where((c) =>
        c.stage == CropStage.harvestReady ||
        c.stage == CropStage.harvested).length;
    final healthLabel = ready > 0
        ? '${AppStrings.farmHealthWatch} · ${AppStrings.farmHealthAction}'
        : (planted > growing ? AppStrings.farmHealthWatch : AppStrings.farmHealthGood);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const IconBadge(
            icon: Icons.health_and_safety_outlined,
            tint: AppColors.tintGreen, color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(AppStrings.farmHealthHeader, style: AppTextStyles.title),
            const SizedBox(height: 2),
            Text(healthLabel,
              style: AppTextStyles.bodySecondary.copyWith(
                color: ready > 0 ? AppColors.warning : AppColors.primary,
                fontWeight: FontWeight.w600)),
          ])),
        ]),
        const SizedBox(height: AppSpacing.md),
        _StageDistributionBar(planted: planted, growing: growing, ready: ready, total: total),
        const SizedBox(height: AppSpacing.md),
        const AppDivider(),
        const SizedBox(height: AppSpacing.md),
        Row(children: [
          Expanded(child: _StageLegend(color: const Color(0xFF8D6E63), label: AppStrings.farmStagePlanted, value: planted, total: total)),
          Expanded(child: _StageLegend(color: AppColors.primary, label: AppStrings.farmStageGrowing, value: growing, total: total)),
          Expanded(child: _StageLegend(color: AppColors.accent, label: AppStrings.farmStageHarvest, value: ready, total: total)),
        ]),
      ]),
    );
  }
}

class _StageDistributionBar extends StatelessWidget {
  const _StageDistributionBar({
    required this.planted, required this.growing, required this.ready, required this.total,
  });
  final int planted, growing, ready, total;

  @override
  Widget build(BuildContext context) {
    double f(int n) => total == 0 ? 0 : n / total;
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Row(children: [
        Expanded(flex: (f(planted) * 1000).round().clamp(0, 1000),
          child: Container(height: 10, color: const Color(0xFF8D6E63))),
        Expanded(flex: (f(growing) * 1000).round().clamp(0, 1000),
          child: Container(height: 10, color: AppColors.primary)),
        Expanded(flex: (f(ready) * 1000).round().clamp(0, 1000),
          child: Container(height: 10, color: AppColors.accent)),
        if (total == 0)
          Expanded(child: Container(height: 10, color: AppColors.surfaceVariant)),
      ]),
    );
  }
}

class _StageLegend extends StatelessWidget {
  const _StageLegend({required this.color, required this.label, required this.value, required this.total});
  final Color color;
  final String label;
  final int value;
  final int total;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0 : ((value / total) * 100).round();
    return Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text('$value  ·  $pct%', style: AppTextStyles.title.copyWith(fontSize: 14)),
      ])),
    ]);
  }
}

class _FarmCard extends StatelessWidget {
  const _FarmCard({
    super.key,
    required this.farm,
    required this.cropsCount,
    required this.onTap,
    required this.onAddCrop,
    required this.onScan,
    required this.onExpense,
    required this.onDelete,
  });
  final Farm farm;
  final int cropsCount;
  final VoidCallback onTap;
  final VoidCallback onAddCrop;
  final VoidCallback onScan;
  final VoidCallback onExpense;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Container(
              width: 52, height: 52,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDark]),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: (farm.photoUrl ?? '').isNotEmpty
                  ? Image.network(
                      farm.photoUrl!,
                      width: 52, height: 52, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(Icons.grass_rounded, color: Color(0xFFD1FAE5), size: 26),
                    )
                  : const Icon(Icons.grass_rounded, color: Color(0xFFD1FAE5), size: 26),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(farm.name, style: AppTextStyles.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 2),
                Flexible(child: Text(
                  farm.location.isEmpty ? 'ঠিকানা দেওয়া হয়নি' : farm.location,
                  style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis,
                )),
              ]),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$cropsCount', style: AppTextStyles.stat.copyWith(fontSize: 24)),
              Text(AppStrings.farmCardCrops, style: AppTextStyles.caption),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
            AppChip(label: '${farm.sizeAcres.toStringAsFixed(1)} ${AppStrings.farmCardAcres}', icon: Icons.straighten_rounded),
            AppChip(label: farm.soilType.bangla, icon: Icons.terrain_rounded),
            if (cropsCount > 0)
              AppChip(
                label: '$cropsCount ${AppStrings.farmCardCrops}',
                icon: Icons.eco_rounded,
                tint: AppColors.tintGreen, color: AppColors.primary,
              ),
          ]),
        ),
        if (farm.notes != null && farm.notes!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(farm.notes!, style: AppTextStyles.bodySecondary, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        const AppDivider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
          child: Row(children: [
            _FarmAction(icon: Icons.add_circle_outline_rounded, label: 'ফসল', onTap: onAddCrop),
            const _ActionDivider(),
            _FarmAction(icon: Icons.center_focus_strong_rounded, label: 'AI', onTap: onScan),
            const _ActionDivider(),
            _FarmAction(icon: Icons.receipt_long_rounded, label: AppStrings.expenses, onTap: onExpense),
            const Spacer(),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
              tooltip: AppStrings.farmCardDelete,
              visualDensity: VisualDensity.compact,
            ),
          ]),
        ),
      ]),
    );
  }
}

class _FarmAction extends StatelessWidget {
  const _FarmAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _ActionDivider extends StatelessWidget {
  const _ActionDivider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 18, color: AppColors.divider);
}

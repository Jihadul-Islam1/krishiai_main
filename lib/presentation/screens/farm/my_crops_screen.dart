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
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/states.dart';
import '../../../data/models/crop.dart';
import '../../../data/models/farm.dart';
import '../../providers/app_providers.dart';

class MyCropsScreen extends ConsumerWidget {
  const MyCropsScreen({super.key, this.farmId});

  /// Optional farmId to scope crops to a single farm. When null, shows all.
  final String? farmId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmsAsync = ref.watch(farmsProvider);
    final cropsAsync = ref.watch(cropsProvider);

    return farmsAsync.when(
      loading: () => const _LoadingShell(),
      error: (e, _) => Scaffold(
        body: ErrorStateView(
          message: e.toString(),
          onRetry: () => ref.invalidate(farmsProvider),
        ),
      ),
      data: (farms) {
        final scopedFarm = farmId == null
            ? null
            : farms.firstWhere(
                (f) => f.id == farmId,
                orElse: () => farms.first,
              );
        return cropsAsync.when(
          loading: () => _LoadingShell(farm: scopedFarm),
          error: (e, _) => Scaffold(
            body: ErrorStateView(
              message: e.toString(),
              onRetry: () => ref.invalidate(cropsProvider),
            ),
          ),
          data: (allCrops) {
            final list = scopedFarm == null
                ? allCrops
                : allCrops
                    .where((c) => c.farmId == scopedFarm.id)
                    .toList();
            return _CropsBody(
              farm: scopedFarm,
              allFarms: farms,
              crops: list,
              onRefresh: () async => ref.invalidate(cropsProvider),
            );
          },
        );
      },
    );
  }
}

class _LoadingShell extends StatelessWidget {
  const _LoadingShell({this.farm});
  final Farm? farm;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ScreenHeader(
          eyebrow: 'OVERVIEW',
          title: farm == null ? AppStrings.myCrops : farm!.name,
          actionIcon: Icons.add_rounded,
          onAction: () => context.push('/farm/add-crop'),
        ),
        const Expanded(child: LoadingState()),
      ],
    );
  }
}

class _CropsBody extends StatelessWidget {
  const _CropsBody({
    required this.farm,
    required this.allFarms,
    required this.crops,
    required this.onRefresh,
  });
  final Farm? farm;
  final List<Farm> allFarms;
  final List<Crop> crops;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final title = farm == null ? AppStrings.myCrops : farm!.name;
    final scoped = farm;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: crops.isEmpty
          ? _EmptyCropsBody(
              title: title,
              scoped: scoped,
              onAdd: () => context.push('/farm/add-crop'),
            )
          : RefreshIndicator(
              onRefresh: onRefresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: ScreenHeader(
                      eyebrow: 'OVERVIEW',
                      title: title,
                      actionIcon: Icons.add_rounded,
                      onAction: () => context.push('/farm/add-crop'),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.huge,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate.fixed([
                        SectionHeader(
                          eyebrow: 'YOUR PLOTS',
                          title: scoped == null
                              ? AppStrings.allCrops
                              : scoped.name,
                          actionLabel: AppStrings.add,
                          onAction: () => context.push('/farm/add-crop'),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        for (final crop in crops) ...[
                          _CropCard(
                            crop: crop,
                            farmName: _farmName(allFarms, crop.farmId),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _farmName(List<Farm> farms, String id) {
    try {
      return farms.firstWhere((f) => f.id == id).name;
    } catch (_) {
      return AppStrings.unknownFarm;
    }
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}



class _CropCard extends StatelessWidget {
  const _CropCard({required this.crop, required this.farmName});
  final Crop crop;
  final String farmName;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM');
    return AppCard(
      onTap: () => context.push('/farm/crop/${crop.id}'),
      elevation: AppElevation.card,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(
                icon: Icons.eco_rounded,
                tint: AppColors.tintGreen,
                color: AppColors.primary,
                size: 48,
                iconSize: 24,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      crop.name,
                      style: AppTextStyles.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${crop.variety} • $farmName',
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _StageChip(stage: crop.stage),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppDivider(),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _MetaItem(
                  icon: Icons.calendar_today_rounded,
                  label: AppStrings.planted,
                  value: df.format(crop.plantingDate),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _MetaItem(
                  icon: Icons.event_rounded,
                  label: AppStrings.expectedHarvest,
                  value: df.format(crop.expectedHarvestDate),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _MetaItem(
                  icon: Icons.straighten_rounded,
                  label: AppStrings.area,
                  value: crop.landSizeAcres.toStringAsFixed(1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.stage});
  final CropStage stage;

  @override
  Widget build(BuildContext context) {
    final color = _stageColor(stage);
    return AppChip(
      label: stage.bangla,
      icon: Icons.spa_rounded,
      tint: color.withValues(alpha: 0.14),
      color: color,
    );
  }

  Color _stageColor(CropStage stage) {
    switch (stage) {
      case CropStage.planted:
        return Colors.brown;
      case CropStage.earlyGrowth:
        return Colors.lightGreen;
      case CropStage.vegetative:
        return AppColors.primary;
      case CropStage.flowering:
        return Colors.pink;
      case CropStage.fruiting:
        return Colors.deepOrange;
      case CropStage.harvestReady:
        return Colors.amber.shade800;
      case CropStage.harvested:
        return Colors.blueGrey;
    }
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: AppTextStyles.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _EmptyCropsBody extends StatelessWidget {
  const _EmptyCropsBody({
    required this.title,
    required this.scoped,
    required this.onAdd,
  });
  final String title;
  final Farm? scoped;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('OVERVIEW', style: AppTextStyles.overline),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(title, style: AppTextStyles.h1),
                      ],
                    ),
                  ),
                  _RoundIconButton(
                    icon: Icons.add_rounded,
                    onTap: onAdd,
                  ),
                ],
              ),
              const Spacer(),
              EmptyState(
                icon: Icons.eco_rounded,
                title: scoped == null
                    ? AppStrings.noCropsYet
                    : AppStrings.noCropsOnFarm,
                message: scoped == null
                    ? AppStrings.addFirstCrop
                    : AppStrings.addFirstCropToFarm,
              ),
              const Spacer(),
              PrimaryButton(
                label: AppStrings.addCrop,
                icon: Icons.add_rounded,
                onPressed: onAdd,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

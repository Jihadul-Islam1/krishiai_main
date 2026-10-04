import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/icon_badge.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/states.dart';
import '../../../data/models/diagnosis.dart';
import '../../../data/models/disease.dart';
import '../../providers/app_providers.dart';

/// Saved diagnosis scans. Read-only history list backed by
/// `LocalStore` key `diagnoses` via `DiagnosisRepository`. Tap a
/// card to re-open the result.
class ScanHistoryScreen extends ConsumerWidget {
  const ScanHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(diagnosesProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.invalidate(diagnosesProvider),
        child: Column(
          children: [
            ScreenHeader(
              eyebrow: AppStrings.tabAi,
              title: AppStrings.scanHistory,
              gradient: const [AppColors.aiCard, AppColors.fieldCard],
              actionIcon: Icons.add_a_photo_outlined,
              actionTooltip: AppStrings.scanHistoryNew,
              onAction: () => context.push('/ai/scan'),
            ),
            Expanded(
              child: async.when(
                data: (list) => list.isEmpty
                    ? const _EmptyHistory()
                    : _HistoryList(items: list),
                loading: () => const LoadingState(
                  message: AppStrings.scanHistoryLoading,
                ),
                error: (e, _) => ErrorStateView(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(diagnosesProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xxl,
        AppSpacing.lg,
        AppSpacing.xxxl,
      ),
      children: const [
        SizedBox(height: AppSpacing.xxl),
        EmptyState(
          icon: Icons.history_rounded,
          title: AppStrings.scanHistoryEmpty,
          message: AppStrings.scanHistoryHint,
        ),
      ],
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.items});
  final List<Diagnosis> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xxxl,
      ),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, i) => _DiagnosisCard(d: items[i]),
    );
  }
}

class _DiagnosisCard extends StatelessWidget {
  const _DiagnosisCard({required this.d});
  final Diagnosis d;

  Color get _severityColor {
    switch (d.severity) {
      case Severity.low:
        return AppColors.severityLow;
      case Severity.medium:
        return AppColors.severityMedium;
      case Severity.high:
        return AppColors.severityHigh;
    }
  }

  void _open(BuildContext context) {
    context.push('/ai/scan/result', extra: {
      'cropName': d.cropName,
      'notes': d.notes,
      'diagnosis': d,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => _open(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(
            icon: Icons.bug_report_outlined,
            tint: _severityColor.withValues(alpha: 0.12),
            color: _severityColor,
            size: 52,
            iconSize: 26,
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
                        d.diseaseName,
                        style: AppTextStyles.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _SeverityChip(
                        severity: d.severity, color: _severityColor),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  d.cropName,
                  style: AppTextStyles.bodySecondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      AppDate.relativeBangla(d.scannedAt),
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    const Icon(Icons.verified_outlined,
                        size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      '${(d.confidence * 100).round()}% ${AppStrings.confidence}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _SeverityChip extends StatelessWidget {
  const _SeverityChip({required this.severity, required this.color});
  final Severity severity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            severity.bangla,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

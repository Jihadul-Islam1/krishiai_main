import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/states.dart';
import '../../../data/models/disease.dart';
import '../../providers/app_providers.dart';

/// Full read-only view of one bundled `Disease`. Hero is severity-colored,
/// followed by crops, symptoms, causes, prevention, management sections.
/// Bottom CTA "ফসল স্ক্যান করুন" jumps to the AI crop doctor for a
/// fresh diagnosis using this disease as a reference.
class DiseaseDetailScreen extends ConsumerWidget {
  const DiseaseDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(diseaseLibraryProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'রোগের বিস্তারিত',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: async.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorStateView(
          message: e.toString(),
          onRetry: () => ref.invalidate(diseaseLibraryProvider),
        ),
        data: (list) {
          final disease = list.cast<Disease?>().firstWhere(
                (d) => d?.id == id,
                orElse: () => null,
              );
          if (disease == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bug_report_outlined,
                        size: 56, color: AppColors.textMuted),
                    const SizedBox(height: AppSpacing.md),
                    const Text('রোগ পাওয়া যায়নি',
                        style: AppTextStyles.h3),
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(
                      label: 'আবার চেষ্টা করুন',
                      icon: Icons.refresh,
                      onPressed: () => ref.invalidate(diseaseLibraryProvider),
                    ),
                  ],
                ),
              ),
            );
          }
          return _DetailBody(disease: disease);
        },
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.disease});
  final Disease disease;

  Color get _severityColor {
    switch (disease.severity) {
      case Severity.low:
        return AppColors.severityLow;
      case Severity.medium:
        return AppColors.severityMedium;
      case Severity.high:
        return AppColors.severityHigh;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            120,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Hero(disease: disease, severityColor: _severityColor),
              const SizedBox(height: AppSpacing.lg),
              _SectionList(
                title: AppStrings.symptoms,
                icon: Icons.visibility_outlined,
                color: AppColors.info,
                items: disease.symptoms,
              ),
              const SizedBox(height: AppSpacing.md),
              _SectionList(
                title: AppStrings.possibleCauses,
                icon: Icons.science_outlined,
                color: AppColors.warning,
                items: disease.causes,
              ),
              const SizedBox(height: AppSpacing.md),
              _SectionList(
                title: AppStrings.prevention,
                icon: Icons.shield_outlined,
                color: AppColors.primary,
                items: disease.prevention,
              ),
              const SizedBox(height: AppSpacing.md),
              _SectionList(
                title: AppStrings.management,
                icon: Icons.healing_outlined,
                color: AppColors.success,
                items: disease.management,
              ),
              const SizedBox(height: AppSpacing.lg),
              _DisclaimerCard(),
            ],
          ),
        ),
        Positioned(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: AppSpacing.lg,
          child: PrimaryButton(
            label: 'ফসল স্ক্যান করুন',
            icon: Icons.camera_alt_outlined,
            onPressed: () => context.go('/ai/scan'),
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.disease, required this.severityColor});
  final Disease disease;
  final Color severityColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            severityColor,
            severityColor.withValues(alpha: 0.78),
          ],
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(Icons.bug_report_outlined,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  disease.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                _InfoRow(label: 'ফসল', value: disease.cropName),
                const SizedBox(width: AppSpacing.lg),
                _InfoRow(label: 'ক্যাটাগরি', value: disease.category),
                const SizedBox(width: AppSpacing.lg),
                _InfoRow(
                    label: AppStrings.severity,
                    value: disease.severity.bangla),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SectionList extends StatelessWidget {
  const _SectionList({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(title, style: AppTextStyles.title)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (items.isEmpty)
            const Text('তথ্য পাওয়া যায়নি',
                style: AppTextStyles.bodySecondary)
          else
            Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 7),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          items[i],
                          style: AppTextStyles.body.copyWith(height: 1.5),
                        ),
                      ),
                    ],
                  ),
                  if (i != items.length - 1)
                    const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline,
              color: AppColors.primaryDark, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              AppStrings.aiDisclaimer,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primaryDark,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

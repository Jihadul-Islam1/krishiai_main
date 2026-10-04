import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/states.dart';
import '../../../data/models/disease.dart';
import '../../providers/app_providers.dart';

/// Bundled disease & pest reference library. Read-only; backs the
/// AI chat suggestions and crop-doctor lookups. Tapping a card
/// navigates to `/library/:id` for the full detail view.
class DiseaseLibraryScreen extends ConsumerStatefulWidget {
  const DiseaseLibraryScreen({super.key});

  @override
  ConsumerState<DiseaseLibraryScreen> createState() =>
      _DiseaseLibraryScreenState();
}

class _DiseaseLibraryScreenState extends ConsumerState<DiseaseLibraryScreen> {
  String _query = '';
  String _category = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(diseaseLibraryProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'রোগ ও পোকার তালিকা',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: async.when(
        data: (list) {
          final categories = <String>{
            for (final d in list) d.category,
          }.toList()
            ..sort();
          final filtered = list.where((d) {
            final matchQ = _query.isEmpty ||
                d.name.toLowerCase().contains(_query.toLowerCase()) ||
                d.cropName.toLowerCase().contains(_query.toLowerCase());
            final matchC = _category.isEmpty || d.category == _category;
            return matchQ && matchC;
          }).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: _SearchBar(
                  value: _query,
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              if (categories.isNotEmpty)
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length + 1,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (context, i) {
                      final cat = i == 0 ? '' : categories[i - 1];
                      final selected = _category == cat;
                      return _CategoryChip(
                        label: cat.isEmpty
                            ? 'সব'
                            : _categoryLabel(cat),
                        selected: selected,
                        onTap: () => setState(() => _category = cat),
                      );
                    },
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: filtered.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 80),
                          EmptyState(
                            icon: Icons.search_off,
                            title: 'কোনো রোগ পাওয়া যায়নি',
                            message: 'অন্য নাম বা ক্যাটাগরি দিয়ে চেষ্টা করুন।',
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          AppSpacing.xxxl,
                        ),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, i) {
                          final d = filtered[i];
                          return _DiseaseCard(
                            disease: d,
                            onTap: () => context.push('/library/${d.id}'),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () =>
            const LoadingState(message: 'রোগের তালিকা লোড হচ্ছে...'),
        error: (e, _) => ErrorStateView(
          message: e.toString(),
          onRetry: () => ref.invalidate(diseaseLibraryProvider),
        ),
      ),
    );
  }

  String _categoryLabel(String cat) {
    switch (cat) {
      case 'rice':
        return 'ধান';
      case 'wheat':
        return 'গম';
      case 'potato':
        return 'আলু';
      case 'tomato':
        return 'টমেটো';
      case 'jute':
        return 'পাট';
      case 'vegetable':
        return 'সবজি';
      case 'fruit':
        return 'ফল';
      default:
        return cat;
    }
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: TextEditingController(text: value)
          ..selection = TextSelection.collapsed(offset: value.length),
        onChanged: onChanged,
        decoration: const InputDecoration(
          hintText: 'রোগ বা ফসল খুঁজুন...',
          prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DiseaseCard extends StatelessWidget {
  const _DiseaseCard({required this.disease, required this.onTap});
  final Disease disease;
  final VoidCallback onTap;

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
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _severityColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.bug_report_outlined,
                color: _severityColor, size: 26),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(disease.name, style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  disease.cropName,
                  style: AppTextStyles.bodySecondary,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    _Pill(
                      color: _severityColor,
                      text: disease.severity.bangla,
                      icon: Icons.warning_amber_outlined,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _Pill(
                      color: AppColors.info,
                      text: '${disease.symptoms.length} লক্ষণ',
                      icon: Icons.list_alt,
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

class _Pill extends StatelessWidget {
  const _Pill({required this.color, required this.text, required this.icon});
  final Color color;
  final String text;
  final IconData icon;

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
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            text,
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

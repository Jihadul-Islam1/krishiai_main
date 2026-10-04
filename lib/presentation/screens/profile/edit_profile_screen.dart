import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/icon_badge.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/states.dart';
import '../../../data/models/farmer.dart';
import '../../providers/app_providers.dart';

const _kEditProfileHeader = ScreenHeader(
  eyebrow: AppStrings.editEyebrow,
  title: AppStrings.editTitle,
  leadingIcon: Icons.edit_rounded,
);

/// Editable form for the farmer profile. Reads the current [Farmer] from
/// [currentFarmerProvider], lets the user modify the editable fields, and
/// persists via [farmerRepoProvider.saveFarmer].
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _upazilaCtrl = TextEditingController();
  final _farmSizeCtrl = TextEditingController();
  final _mainCropCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  String _language = 'bn';
  bool _hydrated = false;
  bool _saving = false;

  static const _languages = [
    _Lang('bn', AppStrings.bangla, AppColors.tintGreen, AppColors.primary),
    _Lang('en', AppStrings.english, AppColors.tintBlue, AppColors.info),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _districtCtrl.dispose();
    _upazilaCtrl.dispose();
    _farmSizeCtrl.dispose();
    _mainCropCtrl.dispose();
    _experienceCtrl.dispose();
    super.dispose();
  }

  void _hydrateFrom(Farmer f) {
    if (_hydrated) return;
    _hydrated = true;
    _nameCtrl.text = f.name;
    _districtCtrl.text = f.district;
    _upazilaCtrl.text = f.upazila;
    _farmSizeCtrl.text = f.farmSizeAcres > 0
        ? f.farmSizeAcres.toString()
        : '';
    _mainCropCtrl.text = f.mainCrop;
    _experienceCtrl.text = f.experienceYears > 0
        ? f.experienceYears.toString()
        : '';
    _language = f.language.isEmpty ? 'bn' : f.language;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = await ref.read(farmerRepoProvider.future);
      final current = await repo.currentFarmer();
      final farmSize = double.tryParse(_farmSizeCtrl.text.trim()) ?? 0.0;
      final exp = int.tryParse(_experienceCtrl.text.trim()) ?? 0;
      final updated = (current ??
              const Farmer(
                id: 'local',
                name: '',
                district: '',
                upazila: '',
                experienceYears: 0,
                farmSizeAcres: 0,
                mainCrop: '',
                language: 'bn',
              ))
          .copyWith(
        name: _nameCtrl.text.trim(),
        district: _districtCtrl.text.trim(),
        upazila: _upazilaCtrl.text.trim(),
        farmSizeAcres: farmSize,
        mainCrop: _mainCropCtrl.text.trim(),
        experienceYears: exp,
        language: _language,
      );
      await repo.saveFarmer(updated);
      ref.invalidate(currentFarmerProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.editSaved)),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppStrings.editSaveFailedPrefix}: $e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmerAsync = ref.watch(currentFarmerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: farmerAsync.when(
        loading: () => Column(
          children: const [
            _kEditProfileHeader,
            Expanded(child: LoadingState()),
          ],
        ),
        error: (e, _) => Column(
          children: [
            _kEditProfileHeader,
            Expanded(
              child: ErrorStateView(
                message: e.toString(),
                onRetry: () => ref.invalidate(currentFarmerProvider),
              ),
            ),
          ],
        ),
        data: (farmer) {
          if (farmer != null) _hydrateFrom(farmer);
          return Column(
            children: [
              _kEditProfileHeader,
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.huge,
                    ),
                    children: [
                      if (farmer == null) ...[
                        AppCard(
                          color: AppColors.warning.withValues(alpha: 0.12),
                          borderColor: AppColors.warning.withValues(alpha: 0.3),
                          elevation: AppElevation.card,
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const IconBadge(
                                icon: Icons.info_outline_rounded,
                                tint: AppColors.tintAmber,
                                color: AppColors.warning,
                                size: 36,
                                iconSize: 18,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Text(
                                  AppStrings.editProfileNotCreatedHint,
                                  style: AppTextStyles.bodySecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      const SectionHeader(
                        eyebrow: 'IDENTITY',
                        title: AppStrings.editIdentityTitle,
                        subtitle: AppStrings.editIdentitySubtitle,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppCard(
                        elevation: AppElevation.card,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppTextField(
                              label: AppStrings.fullName,
                              hint: 'যেমন: রহিম মিয়া',
                              controller: _nameCtrl,
                              prefixIcon: Icons.person_outline_rounded,
                              validator: (v) => (v == null ||
                                      v.trim().isEmpty)
                                  ? AppStrings.editNameRequired
                                  : null,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: AppTextField(
                                    label: AppStrings.district,
                                    hint: 'যেমন: ঢাকা',
                                    controller: _districtCtrl,
                                    prefixIcon:
                                        Icons.location_city_outlined,
                                    validator: (v) => (v == null ||
                                            v.trim().isEmpty)
                                        ? AppStrings.editDistrictRequired
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: AppTextField(
                                    label: AppStrings.upazila,
                                    hint: 'যেমন: সাভার',
                                    controller: _upazilaCtrl,
                                    prefixIcon: Icons.place_outlined,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const SectionHeader(
                        eyebrow: 'AGRICULTURE',
                        title: AppStrings.editFarmTitle,
                        subtitle: AppStrings.editFarmSubtitle,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppCard(
                        elevation: AppElevation.card,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: AppTextField(
                                    label: AppStrings.farmSizeAcres,
                                    hint: 'যেমন: ২.৫',
                                    controller: _farmSizeCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    prefixIcon: Icons.landscape_outlined,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return null;
                                      }
                                      final d = double.tryParse(v.trim());
                                      if (d == null) {
                                        return AppStrings.editFarmSizeInvalid;
                                      }
                                      if (d < 0) {
                                        return AppStrings.editFarmSizeInvalid;
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: AppTextField(
                                    label: AppStrings.experienceYears,
                                    hint: 'যেমন: ৫',
                                    controller: _experienceCtrl,
                                    keyboardType: TextInputType.number,
                                    prefixIcon: Icons.timeline_outlined,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return null;
                                      }
                                      final n = int.tryParse(v.trim());
                                      if (n == null) {
                                        return AppStrings.editExperienceInvalid;
                                      }
                                      if (n < 0 || n > 80) {
                                        return AppStrings.editExperienceInvalid;
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            AppTextField(
                              label: AppStrings.mainCrop,
                              hint: 'যেমন: ধান',
                              controller: _mainCropCtrl,
                              prefixIcon: Icons.agriculture_outlined,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const SectionHeader(
                        eyebrow: 'PREFERENCES',
                        title: AppStrings.editLanguageTitle,
                        subtitle: AppStrings.editLanguageSubtitle,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppCard(
                        elevation: AppElevation.card,
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            for (final l in _languages)
                              AppChip(
                                label: l.bangla,
                                icon: l.code == 'bn'
                                    ? Icons.translate_rounded
                                    : Icons.language_rounded,
                                tint: l.tint,
                                color: l.color,
                                selected: _language == l.code,
                                onTap: () => setState(() => _language = l.code),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxxl),
                      PrimaryButton(
                        label: AppStrings.editSave,
                        icon: Icons.check_rounded,
                        loading: _saving,
                        onPressed: _save,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SecondaryButton(
                        label: AppStrings.editCancel,
                        icon: Icons.close_rounded,
                        onPressed: _saving ? null : () => context.pop(),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Center(
                        child: Text(
                          AppStrings.profileAppFooter,
                          style: AppTextStyles.caption,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// _Lang — language picker option tuple
// ────────────────────────────────────────────────────────────────────────────

class _Lang {
  const _Lang(this.code, this.bangla, this.tint, this.color);
  final String code;
  final String bangla;
  final Color tint;
  final Color color;
}

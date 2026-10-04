import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/models/farmer.dart';
import '../../providers/app_providers.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController(text: 'রহিম মিয়া');
  final _district = TextEditingController(text: 'খুলনা');
  final _upazila = TextEditingController(text: 'বটিয়াঘাটা');
  final _experience = TextEditingController(text: '12');
  final _size = TextEditingController(text: '2.5');
  String _language = 'bn';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _district.dispose();
    _upazila.dispose();
    _experience.dispose();
    _size.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final farmer = Farmer(
      id: 'farmer-${DateTime.now().millisecondsSinceEpoch}',
      name: _name.text.trim(),
      district: _district.text.trim(),
      upazila: _upazila.text.trim(),
      experienceYears: int.tryParse(_experience.text.trim()) ?? 0,
      farmSizeAcres: double.tryParse(_size.text.trim()) ?? 0,
      mainCrop: 'আমন ধান',
      language: _language,
      createdAt: DateTime.now(),
    );
    final repo = await ref.read(farmerRepoProvider.future);
    await repo.saveFarmer(farmer);
    ref.invalidate(currentFarmerProvider);
    if (mounted) context.go('/permissions');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.profileSetup),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const SizedBox(height: 8),
              Text(
                AppStrings.profileSetupHint,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              AppTextField(
                controller: _name,
                label: AppStrings.fullName,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? AppStrings.required
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _district,
                      label: AppStrings.district,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppTextField(
                      controller: _upazila,
                      label: AppStrings.upazila,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _experience,
                      label: AppStrings.experienceYears,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppTextField(
                      controller: _size,
                      label: AppStrings.farmSizeAcres,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                AppStrings.languageLabel,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'bn', label: Text('বাংলা')),
                  ButtonSegment(value: 'en', label: Text('English')),
                ],
                selected: {_language},
                onSelectionChanged: (s) => setState(() => _language = s.first),
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                onPressed: _saving ? null : _save,
                loading: _saving,
                label: AppStrings.continue_,
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

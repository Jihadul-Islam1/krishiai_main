import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/crop.dart';
import '../../../data/models/farm.dart';
import '../../providers/app_providers.dart';

const _uuid = Uuid();

class AddCropScreen extends ConsumerStatefulWidget {
  const AddCropScreen({super.key, this.farmId});
  final String? farmId;

  @override
  ConsumerState<AddCropScreen> createState() => _AddCropScreenState();
}

class _AddCropScreenState extends ConsumerState<AddCropScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _variety = TextEditingController();
  final _size = TextEditingController(text: '0.5');
  final _notes = TextEditingController();
  DateTime _planting = DateTime.now();
  String? _farmId;
  SoilType _soil = SoilType.loam;
  IrrigationType _irrigation = IrrigationType.rainfed;
  CropStage _stage = CropStage.vegetative;
  int _growDays = 90;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _farmId = widget.farmId;
  }

  @override
  void dispose() {
    _name.dispose();
    _variety.dispose();
    _size.dispose();
    _notes.dispose();
    super.dispose();
  }

  DateTime get _harvestDate =>
      _planting.add(Duration(days: _growDays));

  Future<void> _pickPlantingDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _planting,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _planting = picked);
  }

  Future<void> _save(Farm? farm) async {
    if (!_formKey.currentState!.validate()) return;
    if (_farmId == null && farm == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.needFarmFirst)),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final useFarmId = _farmId ?? farm!.id;
      final useSoil =
          _farmId != null ? farm?.soilType ?? _soil : _soil;
      final repo = await ref.read(cropRepoProvider.future);
      await repo.upsert(
        Crop(
          id: _uuid.v4(),
          farmId: useFarmId,
          name: _name.text.trim(),
          variety: _variety.text.trim().isEmpty ? '-' : _variety.text.trim(),
          plantingDate: _planting,
          landSizeAcres: double.tryParse(_size.text.trim()) ?? 0.5,
          soilType: useSoil,
          irrigation: _irrigation,
          expectedHarvestDate: _harvestDate,
          stage: _stage,
          estimatedYieldKg: null,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        ),
      );
      ref.invalidate(cropsProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.editSaveFailedPrefix}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmsAsync = ref.watch(farmsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.addCrop),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: farmsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (farms) {
          if (farms.isEmpty) {
            return const Center(child: Text(AppStrings.needFarmFirst));
          }
          _farmId ??= farms.first.id;
          final farm = farms.firstWhere(
            (f) => f.id == _farmId,
            orElse: () => farms.first,
          );
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _farmId,
                  decoration: const InputDecoration(
                    labelText: AppStrings.selectFarm,
                    border: OutlineInputBorder(),
                  ),
                  items: farms
                      .map((f) => DropdownMenuItem(
                            value: f.id,
                            child: Text(f.name),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _farmId = v;
                        _soil = farms
                            .firstWhere((f) => f.id == v)
                            .soilType;
                      });
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: AppStrings.cropName,
                  controller: _name,
                                      validator: (v) => (v == null || v.trim().isEmpty) ? AppStrings.fieldRequired : null,
                  hint: AppStrings.cropNameHint,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: AppStrings.variety,
                  controller: _variety,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: AppStrings.landSize,
                        controller: _size,
                        keyboardType: TextInputType.number,
                                            validator: (v) => (v == null || v.trim().isEmpty) ? AppStrings.fieldRequired : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppTextField(
                        label: AppStrings.growDays,
                        controller: TextEditingController(
                            text: _growDays.toString()),
                        keyboardType: TextInputType.number,
                        onChanged: (v) {
                          final n = int.tryParse(v);
                          if (n != null && n > 0) _growDays = n;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      const Icon(Icons.calendar_today, color: AppColors.primary),
                  title: Text(AppStrings.plantingDate),
                  subtitle: Text('${_planting.toLocal()}'.split(' ').first),
                  trailing: TextButton(
                    onPressed: _pickPlantingDate,
                    child: const Text(AppStrings.change),
                  ),
                ),
                Text('${AppStrings.expectedHarvest}: ${_harvestDate.toLocal()}'.split(' ').first,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: AppSpacing.md),
                Text(AppStrings.irrigation,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final i in IrrigationType.values)
                      ChoiceChip(
                        label: Text(i.bangla),
                        selected: _irrigation == i,
                        onSelected: (_) => setState(() => _irrigation = i),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(AppStrings.currentStage,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in CropStage.values)
                      ChoiceChip(
                        label: Text(s.bangla),
                        selected: _stage == s,
                        onSelected: (_) => setState(() => _stage = s),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: AppStrings.notesOptional,
                  controller: _notes,
                  maxLines: 3,
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  onPressed: _saving ? null : () => _save(farm),
                  label: _saving ? AppStrings.saving : AppStrings.save,
                  fullWidth: true,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
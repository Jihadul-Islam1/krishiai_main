import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/remote_image_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/farm.dart';
import '../../providers/app_providers.dart';

const _uuid = Uuid();

class AddFarmScreen extends ConsumerStatefulWidget {
  const AddFarmScreen({super.key});

  @override
  ConsumerState<AddFarmScreen> createState() => _AddFarmScreenState();
}

class _AddFarmScreenState extends ConsumerState<AddFarmScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _size = TextEditingController(text: '1.0');
  final _notes = TextEditingController();
  final _ownerName = TextEditingController();
  final _picker = ImagePicker();
  SoilType _soil = SoilType.loam;
  LandOwnership _landOwnership = LandOwnership.owned;
  WaterSource _waterSource = WaterSource.rainwater;
  DateTime? _lastSoilTestDate;
  String? _photoLocalPath;
  String? _photoRemoteUrl;
  bool _uploadingPhoto = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _size.dispose();
    _notes.dispose();
    _ownerName.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    try {
      final xfile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (xfile == null) return;
      if (!mounted) return;
      setState(() {
        _photoLocalPath = xfile.path;
        _uploadingPhoto = true;
      });

      // Upload to Cloudinary under a phone-scoped folder so the same
      // verified number always sees the same picture on any device.
      final store = await ref.read(localStoreProvider.future);
      final phone = store.phoneKey ?? 'anon';
      final storage = ref.read(imageStorageProvider);
      final bytes = await File(xfile.path).readAsBytes();
      final url = await storage.uploadBytes(
        bytes,
        filename: 'farm_${DateTime.now().millisecondsSinceEpoch}.jpg',
        folder: 'krishiai/$phone/farms',
      );
      if (!mounted) return;
      setState(() {
        _photoRemoteUrl = url;
        _uploadingPhoto = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ছবি আপলোড হয়েছে ✓')),
      );
    } on RemoteImageUploadException catch (e) {
      if (!mounted) return;
      setState(() => _uploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ছবি আপলোড ব্যর্থ: ${e.message}\n'
            '.env-এ CLOUDINARY_CLOUD_NAME ও CLOUDINARY_UPLOAD_PRESET আছে কিনা দেখুন।',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ছবি নেওয়া যায়নি: $e')),
      );
    }
  }

  void _clearPhoto() {
    setState(() {
      _photoLocalPath = null;
      _photoRemoteUrl = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final store = await ref.read(localStoreProvider.future);
      final phoneKey = store.phoneKey;
      final repo = await ref.read(farmRepoProvider.future);
      final ownerTrim = _ownerName.text.trim();
      await repo.upsert(
        Farm(
          id: _uuid.v4(),
          name: _name.text.trim(),
          location: _location.text.trim(),
          sizeAcres: double.tryParse(_size.text.trim()) ?? 1.0,
          soilType: _soil,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          ownerName: ownerTrim.isEmpty ? null : ownerTrim,
          landOwnership: _landOwnership,
          waterSource: _waterSource,
          lastSoilTestDate: _lastSoilTestDate,
          photoUrl: _photoRemoteUrl,
          createdAt: DateTime.now(),
        ),
      );
      ref.invalidate(farmsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            phoneKey == null
                ? 'ফার্ম যোগ হয়েছে (স্থানীয়, কোনো ফোন সেশন নেই)'
                : 'ফার্ম যোগ হয়েছে — phoneKey=$phoneKey',
          ),
        ),
      );
      context.pop();
    } catch (e) {
      debugPrint('[AddFarmScreen] save failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'ফার্ম যোগ করা যায়নি: $e\n'
              'Firebase Console → Firestore Rules publish হয়েছে কিনা দেখুন।',
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.addFarm),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'জমির ছবি',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            _PhotoPreview(
              localPath: _photoLocalPath,
              remoteUrl: _photoRemoteUrl,
              uploading: _uploadingPhoto,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _uploadingPhoto
                        ? null
                        : () => _pickAndUploadPhoto(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('ক্যামেরা'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _uploadingPhoto
                        ? null
                        : () => _pickAndUploadPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('গ্যালারি'),
                  ),
                ),
                if (_photoLocalPath != null || _photoRemoteUrl != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  IconButton(
                    onPressed: _uploadingPhoto ? null : _clearPhoto,
                    icon: const Icon(Icons.delete_outline),
                    color: AppColors.danger,
                    tooltip: 'ছবি মুছুন',
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            // ----- Name + location -----
            AppTextField(
              label: AppStrings.farmName,
              controller: _name,
              hint: AppStrings.farmNameHint,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? AppStrings.fieldRequired
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: AppStrings.farmLocation,
              controller: _location,
              hint: AppStrings.farmLocationHint,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? AppStrings.fieldRequired
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: AppStrings.farmSize,
              controller: _size,
              keyboardType: TextInputType.number,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? AppStrings.fieldRequired
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              AppStrings.soilType,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in SoilType.values)
                  ChoiceChip(
                    label: Text(s.bangla),
                    selected: _soil == s,
                    onSelected: (_) => setState(() => _soil = s),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: AppStrings.farmOwnerName,
              controller: _ownerName,
              hint: AppStrings.farmOwnerNameHint,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              AppStrings.farmLandOwnership,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in LandOwnership.values)
                  ChoiceChip(
                    label: Text(o.bangla),
                    selected: _landOwnership == o,
                    onSelected: (_) => setState(() => _landOwnership = o),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              AppStrings.farmWaterSource,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final w in WaterSource.values)
                  ChoiceChip(
                    label: Text(w.bangla),
                    selected: _waterSource == w,
                    onSelected: (_) => setState(() => _waterSource = w),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              AppStrings.farmLastSoilTest,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                _lastSoilTestDate == null
                    ? AppStrings.pickDate
                    : AppDate.full(_lastSoilTestDate!),
              ),
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _lastSoilTestDate ?? now,
                  firstDate: DateTime(now.year - 10),
                  lastDate: now,
                );
                if (picked != null) setState(() => _lastSoilTestDate = picked);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: AppStrings.notesOptional,
              controller: _notes,
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              onPressed: _saving ? null : _save,
              label: _saving ? AppStrings.saving : AppStrings.save,
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// Preview tile for the picked + uploaded farm photo. While the upload
/// is still running we show the local file with a spinner overlay; once
/// Cloudinary returns a URL we just render the remote image.
class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({
    required this.localPath,
    required this.remoteUrl,
    required this.uploading,
  });

  final String? localPath;
  final String? remoteUrl;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (remoteUrl != null && remoteUrl!.isNotEmpty)
              Image.network(
                remoteUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(),
              )
            else if (localPath != null && localPath!.isNotEmpty)
              Image.file(
                File(localPath!),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(),
              )
            else
              _placeholder(),
            if (uploading)
              Container(
                color: Colors.black54,
                alignment: Alignment.center,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Cloudinary-তে আপলোড হচ্ছে…',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.surfaceVariant,
      alignment: Alignment.center,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.landscape_outlined,
              size: 56, color: AppColors.textSecondary),
          SizedBox(height: 8),
          Text(
            'ক্যামেরা বা গ্যালারি থেকে ছবি যোগ করুন\n(ঐচ্ছিক — আপলোড Cloudinary-তে)',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

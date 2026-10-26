import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../presentation/providers/app_providers.dart';
import 'remote_image_storage.dart';
import 'user_photo_upload.dart';

/// Pick / replace / remove the logged-in farmer's profile photo.
///
/// The image goes to ImgBB (named with the phone digits and recorded under
/// `users/{phone}/photos`) and the URL is saved in
/// `users/{phone}/profile/me.profileImagePath`.
class ProfilePhotoService {
  ProfilePhotoService._();

  static const _remove = Object();

  /// Shows the camera / gallery / remove sheet and applies the choice.
  static Future<void> change(BuildContext context, WidgetRef ref) async {
    final hasPhoto =
        (ref.read(currentFarmerProvider).valueOrNull?.profileImagePath ?? '')
            .isNotEmpty;
    final choice = await showModalBottomSheet<Object>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('ক্যামেরা দিয়ে ছবি তুলুন'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('গ্যালারি থেকে বেছে নিন'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('ছবি সরান'),
                onTap: () => Navigator.pop(ctx, _remove),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = await ref.read(farmerRepoProvider.future);
      final farmer = await repo.currentFarmer();
      if (farmer == null) return;

      if (choice == _remove) {
        await repo.saveFarmer(farmer.copyWith(clearProfileImage: true));
        ref.invalidate(currentFarmerProvider);
        return;
      }

      final xfile = await ImagePicker().pickImage(
        source: choice as ImageSource,
        imageQuality: 80,
        maxWidth: 800,
      );
      if (xfile == null) return;

      messenger.showSnackBar(
        const SnackBar(content: Text('ছবি আপলোড হচ্ছে…')),
      );
      final image = await uploadUserPhoto(
        ref,
        await File(xfile.path).readAsBytes(),
        kind: 'profile',
      );
      await repo.saveFarmer(farmer.copyWith(profileImagePath: image.url));
      ref.invalidate(currentFarmerProvider);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('প্রোফাইল ছবি আপডেট হয়েছে ✓')));
    } on RemoteImageUploadException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('ছবি আপলোড ব্যর্থ: ${e.message}')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('ছবি আপডেট ব্যর্থ: $e')));
    }
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/farm.dart';
import '../../presentation/providers/app_providers.dart';
import 'remote_image_storage.dart';
import 'user_photo_upload.dart';

/// Add / replace / remove the photo of one of the farmer's farms.
///
/// The picture is uploaded to ImgBB (recorded under `users/{phone}/photos`)
/// and its URL is saved on the farm doc (`users/{phone}/farms/{id}.photoUrl`),
/// so the Home carousel, My Farm list and Farm detail all show it.
class FarmPhotoService {
  FarmPhotoService._();

  static const _remove = Object();

  static Future<void> change(
    BuildContext context,
    WidgetRef ref,
    Farm farm,
  ) async {
    final hasPhoto = (farm.photoUrl ?? '').isNotEmpty;
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
      final repo = await ref.read(farmRepoProvider.future);
      if (choice == _remove) {
        await repo.upsert(farm.copyWith(clearPhotoUrl: true));
        ref.invalidate(farmsProvider);
        return;
      }
      final xfile = await ImagePicker().pickImage(
        source: choice as ImageSource,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (xfile == null) return;

      messenger.showSnackBar(
        const SnackBar(content: Text('জমির ছবি আপলোড হচ্ছে…')),
      );
      final image = await uploadUserPhoto(
        ref,
        await File(xfile.path).readAsBytes(),
        kind: 'farm',
      );
      await repo.upsert(farm.copyWith(photoUrl: image.url));
      ref.invalidate(farmsProvider);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('জমির ছবি আপডেট হয়েছে ✓')));
    } on RemoteImageUploadException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('ছবি আপলোড ব্যর্থ: ${e.message}')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('ছবি আপডেট ব্যর্থ: $e')));
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/providers/app_providers.dart';
import '../utils/phone_key.dart';
import 'fs_paths.dart';
import 'remote_image_storage.dart';

/// Uploads a photo for the logged-in farmer and records it in
/// `users/{phone}/photos/{id}` ({kind, url, deleteUrl, createdAt}).
///
/// ImgBB has no per-user folders, so this Firestore registry (scoped by the
/// phone number) is what ties every picture to exactly one farmer; the phone
/// digits are also baked into the image file name.
///
/// [kind]: `profile`, `farm`, `scan`, ...
Future<RemoteImage> uploadUserPhoto(
  WidgetRef ref,
  List<int> bytes, {
  required String kind,
}) async {
  final store = await ref.read(localStoreProvider.future);
  final phone = store.phoneKey;
  if (phone == null) {
    throw RemoteImageUploadException('ছবি আপলোড করতে আগে লগইন করুন');
  }
  final id = DateTime.now().millisecondsSinceEpoch.toString();
  final image = await ref
      .read(imageStorageProvider)
      .upload(bytes, name: '${PhoneKey.folderId(phone)}_${kind}_$id');
  try {
    await FsPaths.photoDoc(phone, id).set({
      'id': id,
      'kind': kind,
      'url': image.url,
      'deleteUrl': image.deleteUrl,
      'createdAt': DateTime.now().toIso8601String(),
      'uploadedAt': FieldValue.serverTimestamp(),
    });
  } catch (_) {
    // The image is already uploaded and its URL is saved on the profile/farm
    // doc; a missing registry row must not fail the upload.
  }
  return image;
}

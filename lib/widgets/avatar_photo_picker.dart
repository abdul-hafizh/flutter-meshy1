import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/auth_controller.dart';

/// Camera / gallery sheet → upload as the profile photo. [onUploading] flips
/// true once a photo is picked and false when the upload finishes, so the
/// caller can show a spinner on its avatar.
Future<void> pickAndUploadAvatar(BuildContext context, {ValueChanged<bool>? onUploading}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Ambil foto'),
            onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Pilih dari galeri'),
            onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null) return;
  final file = await ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 1024, maxHeight: 1024);
  if (file == null || !context.mounted) return;
  onUploading?.call(true);
  final bytes = await file.readAsBytes();
  final name = file.name.contains('.') ? file.name : '${file.name}.jpg';
  if (!context.mounted) return;
  final error = await context.read<AuthController>().uploadAvatar(bytes, name);
  if (!context.mounted) return;
  onUploading?.call(false);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'Foto profil diperbarui.')));
}

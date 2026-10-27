import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Thin wrapper around image_picker so screens stay UI-only.
/// Photos are downscaled + compressed before they reach storage.
class AvatarPicker {
  AvatarPicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  static final AvatarPicker instance = AvatarPicker();

  final ImagePicker _picker;

  Future<Uint8List?> pick(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
      preferredCameraDevice: CameraDevice.front,
    );
    if (file == null) return null;
    return file.readAsBytes();
  }
}

import 'dart:math';
import 'dart:typed_data';

import 'package:supabase/supabase.dart';

class RecipePhoto {
  const RecipePhoto(this.bytes, this.extension, this.contentType);
  final Uint8List bytes;
  final String extension;
  final String contentType;
  static const maxBytes = 8 * 1024 * 1024;

  static RecipePhoto fromBytes(Uint8List bytes) {
    if (bytes.length > maxBytes) {
      throw const FormatException('Das Bild darf höchstens 8 MB groß sein.');
    }
    if (bytes.length >= 12) {
      if (bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff) {
        return RecipePhoto(bytes, 'jpg', 'image/jpeg');
      }
      if (bytes[0] == 137 &&
          bytes[1] == 80 &&
          bytes[2] == 78 &&
          bytes[3] == 71 &&
          bytes[4] == 13 &&
          bytes[5] == 10 &&
          bytes[6] == 26 &&
          bytes[7] == 10) {
        return RecipePhoto(bytes, 'png', 'image/png');
      }
      if (String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
          String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
        return RecipePhoto(bytes, 'webp', 'image/webp');
      }
    }
    throw const FormatException(
      'Bitte ein JPG-, PNG- oder WebP-Bild auswählen.',
    );
  }
}

abstract interface class RecipeImageUploader {
  Future<String> upload(RecipePhoto photo);
}

class SupabaseRecipeImageUploader implements RecipeImageUploader {
  SupabaseRecipeImageUploader(this.client);
  final SupabaseClient client;
  @override
  Future<String> upload(RecipePhoto photo) async {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Bitte erneut anmelden.');
    final nonce = List.generate(
      16,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final path = '${user.id}/$nonce.${photo.extension}';
    final bucket = client.storage.from('recipe-images');
    await bucket.uploadBinary(
      path,
      photo.bytes,
      fileOptions: FileOptions(contentType: photo.contentType, upsert: false),
    );
    return bucket.getPublicUrl(path);
  }
}

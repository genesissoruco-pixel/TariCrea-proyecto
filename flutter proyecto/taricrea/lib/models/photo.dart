import 'dart:typed_data';
import 'dart:ui' as ui;

class UploadPhoto {
  const UploadPhoto(this.bytes, this.mime);

  final Uint8List bytes;
  final String mime;

  String get filename =>
      'foto.${mime == 'image/jpeg' ? 'jpg' : mime.split('/').last}';

  static const maxBytes = 5 * 1024 * 1024;

  static Future<UploadPhoto> validate(Uint8List bytes) async {
    if (bytes.length > maxBytes) {
      throw const FormatException('La fotografía puede pesar hasta 5 MB.');
    }
    final String mime;
    if (bytes.length > 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) {
      mime = 'image/jpeg';
    } else if (bytes.length > 8 &&
        bytes[0] == 137 &&
        String.fromCharCodes(bytes.sublist(1, 4)) == 'PNG') {
      mime = 'image/png';
    } else if (bytes.length > 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      mime = 'image/webp';
    } else {
      throw const FormatException('Selecciona una fotografía JPG, PNG o WebP.');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        if (descriptor.width > 8192 ||
            descriptor.height > 8192 ||
            descriptor.width * descriptor.height > 20000000) {
          throw const FormatException(
            'La fotografía supera las dimensiones admitidas.',
          );
        }
      } finally {
        descriptor.dispose();
      }
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('No se pudo leer la fotografía.');
    } finally {
      buffer.dispose();
    }
    return UploadPhoto(bytes, mime);
  }
}

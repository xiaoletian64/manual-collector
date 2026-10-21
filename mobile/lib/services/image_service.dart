import 'dart:typed_data';
import 'package:image/image.dart' as img;

// Runs in an isolate. Bake EXIF before OCR so image, OCR and PDF use identical coordinates.
Uint8List normalizeImage(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('无法读取这张图片，请选择 JPG 或 PNG');
  }
  var image = img.bakeOrientation(decoded);
  if (image.width > 2600 || image.height > 2600) {
    image = img.copyResize(
      image,
      width: image.width >= image.height ? 2600 : null,
      height: image.height > image.width ? 2600 : null,
      interpolation: img.Interpolation.average,
    );
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 92));
}

Uint8List rotateImage(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) {
    throw const FormatException('图片无法读取');
  }
  return Uint8List.fromList(
    img.encodeJpg(img.copyRotate(image, angle: 90), quality: 95),
  );
}

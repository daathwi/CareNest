import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:io';

class VisionResult {
  final Uint8List rawBytes;      // Raw RGB for the Model
  final Uint8List displayBytes;  // Encoded JPEG for UI
  final int width;
  final int height;

  VisionResult({
    required this.rawBytes, 
    required this.displayBytes, 
    required this.width, 
    required this.height
  });
}

class VisionService {
  final ImagePicker _picker = ImagePicker();

  /// Captures or picks a photo and processes it into raw RGB bytes for Gemma 4.
  /// Implements dynamic compression based on total image count to prevent OOM.
  Future<VisionResult?> pickAndProcessImage({
    required ImageSource source,
    required int totalAttachments
  }) async {
    try {
      // 1. Capture/Pick Photo
      final XFile? photo = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
      );

      if (photo == null) return null;

      // 2. Load and Decode
      final bytes = await File(photo.path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      // 3. Dynamic Compression Strategy
      int targetSize;
      if (totalAttachments == 1) {
        targetSize = 896; // No compression (High Res)
      } else if (totalAttachments == 2) {
        targetSize = 448; // Mild compression
      } else {
        targetSize = 224; // Moderate/Aggressive compression for 3 images
      }

      // Preserve aspect ratio while fitting into target size
      final resized = img.copyResize(
        decoded, 
        width: decoded.width > decoded.height ? targetSize : null, 
        height: decoded.height >= decoded.width ? targetSize : null,
        maintainAspect: true,
        interpolation: img.Interpolation.linear
      );

      // 4. Extract Raw RGB Bytes (3 bytes per pixel) for Gemma 4
      final rawRgb = Uint8List(resized.width * resized.height * 3);
      int index = 0;
      for (var y = 0; y < resized.height; y++) {
        for (var x = 0; x < resized.width; x++) {
          final pixel = resized.getPixel(x, y);
          rawRgb[index++] = pixel.r.toInt();
          rawRgb[index++] = pixel.g.toInt();
          rawRgb[index++] = pixel.b.toInt();
        }
      }

      // 5. Encode UI-ready JPEG
      final displayBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 85));

      return VisionResult(
        rawBytes: rawRgb,
        displayBytes: displayBytes,
        width: resized.width,
        height: resized.height,
      );
    } catch (e) {
      print("Vision Processing Error: $e");
      return null;
    }
  }
}

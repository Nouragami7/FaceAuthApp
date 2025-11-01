import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

class Nv21Converter {
  static img.Image nv21ToImage(Uint8List nv21, int width, int height) {
    final out = img.Image(width, height);
    final ySize = width * height;
    int yIndex = 0;
    for (int j = 0; j < height; j++) {
      final uvRowStart = ySize + (j >> 1) * width;
      for (int i = 0; i < width; i++) {
        final y = nv21[yIndex] & 0xFF;
        final uvIndex = uvRowStart + (i & ~1);
        final v = nv21[uvIndex] & 0xFF;
        final u = nv21[uvIndex + 1] & 0xFF;
        final c = y - 16;
        final d = u - 128;
        final e = v - 128;
        int r = (1.164 * c + 1.596 * e).round();
        int g = (1.164 * c - 0.392 * d - 0.813 * e).round();
        int b = (1.164 * c + 2.017 * d).round();
        if (r < 0)
          r = 0;
        else if (r > 255)
          r = 255;
        if (g < 0)
          g = 0;
        else if (g > 255)
          g = 255;
        if (b < 0)
          b = 0;
        else if (b > 255)
          b = 255;
        out.setPixel(i, j, img.getColor(r, g, b));
        yIndex++;
      }
    }
    return out;
  }

  static Uint8List yuv420ToNv21(CameraImage image) {
    if (image.planes.length < 3) {
      throw StateError(
        'Expected 3 planes for YUV420, got ${image.planes.length}',
      );
    }
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final yRowStride = yPlane.bytesPerRow;
    final uvRowStride = uPlane.bytesPerRow;
    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;
    final ySize = width * height;
    final uvSize = (width * height) ~/ 2;
    final out = Uint8List(ySize + uvSize);
    int o = 0;
    final yBytes = yPlane.bytes;
    for (int row = 0; row < height; row++) {
      final start = row * yRowStride;
      out.setRange(o, o + width, yBytes.sublist(start, start + width));
      o += width;
    }
    final uBytes = uPlane.bytes;
    final vBytes = vPlane.bytes;
    int uvOut = ySize;
    final halfH = height ~/ 2;
    final halfW = width ~/ 2;
    for (int row = 0; row < halfH; row++) {
      final uRowStart = row * uvRowStride;
      final vRowStart = row * vPlane.bytesPerRow;
      for (int col = 0; col < halfW; col++) {
        final uIndex = uRowStart + col * uPixelStride;
        final vIndex = vRowStart + col * vPixelStride;
        out[uvOut++] = vBytes[vIndex];
        out[uvOut++] = uBytes[uIndex];
      }
    }
    return out;
  }

  static img.Image? latestNv21ToImage((Uint8List, InputImageMetadata)? pair) {
    if (pair == null) return null;
    final (nv21, meta) = pair;
    return nv21ToImage(nv21, meta.size.width.toInt(), meta.size.height.toInt());
  }
}

import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'histogram_equalizer.dart';
import 'vector_norm.dart';

class DescriptorService {
  final int size;
  final bool l2Normalize;

  DescriptorService({this.size = 32, this.l2Normalize = true}) {
    print('[Descriptor][Init] size=$size l2Normalize=$l2Normalize');
  }

  Float32List imageToDescriptor(img.Image faceImg) {
    print('[Descriptor][Preprocess] input=${faceImg.width}x${faceImg.height} → target=${size}x$size');
    final resized = img.copyResize(
      faceImg,
      width: size,
      height: size,
      interpolation: img.Interpolation.cubic,
    );
    final List<double> gray = List<double>.filled(size * size, 0.0);
    int idx = 0;
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        final int color = resized.getPixel(x, y);
        final int r = img.getRed(color);
        final int g = img.getGreen(color);
        final int b = img.getBlue(color);
        final double luma = (0.299 * r + 0.587 * g + 0.114 * b);
        gray[idx++] = luma;
      }
    }
    final eq = HistogramEqualizer.equalize(gray);
    final out = Float32List(eq.length);
    double minV = eq.reduce(math.min);
    double maxV = eq.reduce(math.max);
    final double range = (maxV - minV).abs() < 1e-6 ? 1.0 : (maxV - minV);
    for (int i = 0; i < eq.length; i++) {
      out[i] = (eq[i] - minV) / range;
    }
    if (l2Normalize) {
      VectorNorm.l2(out);
    }
    final mean = out.reduce((a, b) => a + b) / out.length;
    double sumSq = 0.0;
    for (final v in out) {
      final d = v - mean;
      sumSq += d * d;
    }
    final std = math.sqrt(sumSq / out.length);
    print('[Descriptor][Stats] len=${out.length} mean=${mean.toStringAsFixed(3)} std=${std.toStringAsFixed(3)} min=${minV.toStringAsFixed(1)} max=${maxV.toStringAsFixed(1)}');
    print('[Descriptor][Done] vector generated ✓');
    return out;
  }

  Uint8List float32ListToBytes(Float32List f) => f.buffer.asUint8List();
  Float32List bytesToFloat32List(Uint8List b) => Float32List.view(b.buffer, b.offsetInBytes, b.lengthInBytes ~/ 4);
}

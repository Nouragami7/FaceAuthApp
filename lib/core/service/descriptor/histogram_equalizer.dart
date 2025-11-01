import 'dart:math' as math;

class HistogramEqualizer {
  static List<double> equalize(List<double> pixels) {
    const int levels = 256;
    final hist = List<int>.filled(levels, 0);
    for (final v in pixels) {
      final int idx = v.clamp(0, 255).toInt();
      hist[idx]++;
    }
    final cdf = List<int>.filled(levels, 0);
    cdf[0] = hist[0];
    for (int i = 1; i < levels; i++) {
      cdf[i] = cdf[i - 1] + hist[i];
    }
    final int total = pixels.length;
    final int cdfMin = cdf.firstWhere((v) => v > 0, orElse: () => 0);
    final eqPixels = List<double>.filled(pixels.length, 0.0);
    for (int i = 0; i < pixels.length; i++) {
      final int val = pixels[i].clamp(0, 255).toInt();
      final double newVal =
          (((cdf[val] - cdfMin) * 255.0) / math.max(1, (total - cdfMin)))
              .clamp(0, 255)
              .toDouble();
      eqPixels[i] = newVal;
    }
    return eqPixels;
  }
}

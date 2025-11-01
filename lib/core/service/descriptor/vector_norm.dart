import 'dart:math' as math;
import 'dart:typed_data';

class VectorNorm {
  static void l2(Float32List v) {
    double norm = 0.0;
    for (final x in v) {
      norm += x * x;
    }
    norm = math.sqrt(norm);
    if (norm > 1e-9) {
      for (int i = 0; i < v.length; i++) {
        v[i] = v[i] / norm;
      }
    }
  }
}

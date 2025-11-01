import 'dart:math' as math;
import 'dart:typed_data';

double cosineSimilarity(Float32List a, Float32List b) {
  double dot = 0, na = 0, nb = 0;
  final n = math.min(a.length, b.length);
  for (int i = 0; i < n; i++) {
    final x = a[i], y = b[i];
    dot += x * y;
    na += x * x;
    nb += y * y;
  }
  final denom = math.sqrt(na) * math.sqrt(nb);
  return denom == 0 ? -1 : dot / denom;
}
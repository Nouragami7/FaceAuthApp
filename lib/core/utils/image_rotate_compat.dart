import 'package:image/image.dart' as img;

img.Image rotate90Compat(img.Image src, {int times = 1}) {
  int t = times % 4;
  if (t == 0) return src;
  var out = src;
  for (int i = 0; i < t; i++) {
    out = img.copyRotate(out, 90);
  }
  return out;
}
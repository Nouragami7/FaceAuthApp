import 'package:flutter/foundation.dart';

class FpsCounter {
  int _frames = 0;
  DateTime _windowStart = DateTime.now();

  void onFrame({String tag = 'FPS'}) {
    _frames++;
    final now = DateTime.now();
    final elapsed = now.difference(_windowStart);
    if (elapsed.inMilliseconds >= 1000) {
      final fps = _frames / (elapsed.inMilliseconds / 1000.0);
      debugPrint(
        '[$tag] ~${fps.toStringAsFixed(1)} fps (frames=$_frames, window=${elapsed.inMilliseconds}ms)',
      );
      _frames = 0;
      _windowStart = now;
    }
  }

  void reset() {
    _frames = 0;
    _windowStart = DateTime.now();
  }
}

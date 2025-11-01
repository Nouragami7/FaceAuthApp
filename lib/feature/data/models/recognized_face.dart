import 'dart:ui';

class RecognizedFace {
  final int userId;
  final String name;
  final double score;
  final Rect box;

  RecognizedFace({
    required this.userId,
    required this.name,
    required this.score,
    required this.box,
  });
}

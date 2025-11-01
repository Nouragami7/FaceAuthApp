import 'dart:ui' as ui;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class DetectionResult {
  final List<Face> faces;
  final ui.Size imageSize;
  final InputImageRotation imageRotation;

  DetectionResult({
    required this.faces,
    required this.imageSize,
    required this.imageRotation,
  });
}

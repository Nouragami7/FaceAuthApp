import 'package:camera/camera.dart' show CameraLensDirection, CameraPreview;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../presentation/cubit/live/live_rec_cubit.dart';
import '../../presentation/cubit/live/live_rec_state.dart';
import '../../../core/utils/vision_mapping.dart';
import '../../../feature/data/models/recognized_face.dart';

class LiveRecognitionPage extends StatelessWidget {
  const LiveRecognitionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Recognition')),
      body: BlocBuilder<LiveRecCubit, LiveRecState>(
        builder: (context, state) {
          final cam = state.camera;
          if (cam == null || !state.cameraReady) {
            return const Center(child: CircularProgressIndicator());
          }

          return LayoutBuilder(
            builder: (ctx, cons) {
              final widgetSize = Size(cons.maxWidth, cons.maxHeight);
              final isFront = cam.description.lensDirection == CameraLensDirection.front;

              final imgSize = state.imageSize;
              final faces = state.faces;

              if (imgSize == null || faces.isEmpty) {
                return Stack(
                  fit: StackFit.expand,
                  children: [CameraPreview(cam)],
                );
              }

              final drawItems = <_DrawItem>[];
              for (final f in faces) {
                final best = bestForFace<RecognizedFace>(
                  f.boundingBox,
                  state.matches,
                  (m) => m.box,
                );

                final isKnown = best != null && best.score >= state.minCosine;
                final label = isKnown ? best!.name : 'Unknown';

                final rect = mapRectCover(
                  r: f.boundingBox,
                  imageSize: imgSize,
                  widgetSize: widgetSize,
                  mirror: isFront,
                  rotation: state.lastRotation ?? InputImageRotation.rotation0deg,
                );

                const textHeight = 20.0;
                final labelTop = (rect.top - (textHeight + 8) < 0)
                    ? rect.top + 4
                    : rect.top - (textHeight + 8);

                drawItems.add(_DrawItem(
                  rect: rect,
                  label: label,
                  labelTop: labelTop,
                  isKnown: isKnown,
                ));
              }

              return Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(cam),
                  CustomPaint(painter: _FacePainter(drawItems)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _DrawItem {
  final Rect rect;
  final String label;
  final double labelTop;
  final bool isKnown;
  _DrawItem({
    required this.rect,
    required this.label,
    required this.labelTop,
    required this.isKnown,
  });
}

class _FacePainter extends CustomPainter {
  final List<_DrawItem> items;
  _FacePainter(this.items);

  @override
  void paint(Canvas canvas, Size size) {
    final boxPaintKnown = Paint()..style = PaintingStyle.stroke..strokeWidth = 3;
    final boxPaintUnknown = Paint()..style = PaintingStyle.stroke..strokeWidth = 3;

    for (final it in items) {
      final p = it.isKnown ? boxPaintKnown : boxPaintUnknown;
      p.color = it.isKnown ? Colors.greenAccent : Colors.redAccent;

      canvas.drawRect(it.rect, p);

      final tp = TextPainter(
        text: TextSpan(
          text: it.label,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      const padding = 6.0;
      final bgRect = Rect.fromLTWH(
        it.rect.left,
        it.labelTop,
        tp.width + padding * 2,
        tp.height + 8,
      );

      final bgPaint = Paint()
        ..color = (it.isKnown ? Colors.green : Colors.red).withOpacity(0.7);

      canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(6)), bgPaint);
      tp.paint(canvas, Offset(bgRect.left + padding, bgRect.top + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _FacePainter oldDelegate) => oldDelegate.items != items;
}

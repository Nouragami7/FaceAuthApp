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
          return _LivePreview(camera: cam, state: state);
        },
      ),
    );
  }
}

class _LivePreview extends StatefulWidget {
  final dynamic camera;
  final LiveRecState state;
  const _LivePreview({required this.camera, required this.state});

  @override
  State<_LivePreview> createState() => _LivePreviewState();
}

class _LivePreviewState extends State<_LivePreview> {
  List<_DrawItem> _lastDrawItems = [];
  DateTime _lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Widget build(BuildContext context) {
    final cam = widget.camera;
    final imgSize = widget.state.imageSize;
    final faces = widget.state.faces;
    final isFront = cam.description.lensDirection == CameraLensDirection.front;
    final widgetSize = MediaQuery.of(context).size;

    final drawNow = <_DrawItem>[];
    if (imgSize != null && faces.isNotEmpty) {
      for (final f in faces) {
        final best = bestForFace<RecognizedFace>(
          f.boundingBox,
          widget.state.matches,
          (m) => m.box,
        );

        final isKnown = best != null && best.score >= widget.state.minCosine;
        final label = isKnown ? best!.name : 'Unknown';

        Rect rect = mapRectCover(
          r: f.boundingBox,
          imageSize: imgSize,
          widgetSize: widgetSize,
          mirror: isFront,
          rotation:
              widget.state.lastRotation ?? InputImageRotation.rotation0deg,
        );

        final expandX = rect.width * 0.05;
        final expandY = rect.height * 0.10;

        rect = Rect.fromLTRB(
          rect.left - expandX,
          rect.top - expandY,
          rect.right + expandX,
          rect.bottom + expandY,
        );

        const textHeight = 20.0;
        final labelTop =
            (rect.top - (textHeight + 8) < 0)
                ? rect.top + 4
                : rect.top - (textHeight + 8);

        drawNow.add(
          _DrawItem(
            rect: rect,
            label: label,
            labelTop: labelTop,
            isKnown: isKnown,
          ),
        );
      }
      if (drawNow.isNotEmpty) {
        _lastDrawItems = drawNow;
        _lastUpdate = DateTime.now();
      }
    }

    final hasFaces = faces.isNotEmpty && drawNow.isNotEmpty;
    final keep =
        hasFaces &&
        DateTime.now().difference(_lastUpdate).inMilliseconds < 3000;
    final itemsToPaint = keep ? _lastDrawItems : const <_DrawItem>[];

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(cam),
        if (itemsToPaint.isNotEmpty)
          CustomPaint(painter: _FacePainter(itemsToPaint)),
      ],
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
    final boxPaintKnown =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
    final boxPaintUnknown =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;

    for (final it in items) {
      final p = it.isKnown ? boxPaintKnown : boxPaintUnknown;
      p.color = it.isKnown ? Colors.greenAccent : Colors.redAccent;

      canvas.drawRect(it.rect, p);

      final tp = TextPainter(
        text: TextSpan(
          text: it.label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
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

      final bgPaint =
          Paint()
            ..color = (it.isKnown ? Colors.green : Colors.red).withOpacity(0.7);

      canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, const Radius.circular(6)),
        bgPaint,
      );
      tp.paint(canvas, Offset(bgRect.left + padding, bgRect.top + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _FacePainter oldDelegate) =>
      oldDelegate.items != items;
}

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

// IoU between two rects
double iou(Rect a, Rect b) {
  final i = Rect.fromLTRB(
    a.left > b.left ? a.left : b.left,
    a.top > b.top ? a.top : b.top,
    a.right < b.right ? a.right : b.right,
    a.bottom < b.bottom ? a.bottom : b.bottom,
  );
  final inter = (i.width <= 0 || i.height <= 0) ? 0.0 : i.width * i.height;
  final union = a.width * a.height + b.width * b.height - inter;
  return union > 0 ? inter / union : 0.0;
}

// Pick best match for a face by IoU with a threshold
T? bestForFace<T>(Rect faceRect, List<T> all, Rect Function(T) getBox, {double minIou = 0.30}) {
  T? best;
  double bestIou = 0;
  for (final m in all) {
    final v = iou(faceRect, getBox(m));
    if (v > bestIou) {
      bestIou = v;
      best = m;
    }
  }
  return (bestIou >= minIou) ? best : null;
}

// Map rect from image-space to preview widget-space using BoxFit.cover + optional mirror (front cam)
Rect mapRectCover({
  required Rect r,
  required Size imageSize,
  required Size widgetSize,
  required bool mirror,
  required InputImageRotation rotation,
}) {
  final bool swap =
      rotation == InputImageRotation.rotation90deg ||
      rotation == InputImageRotation.rotation270deg;

  final double imageW = swap ? imageSize.height : imageSize.width;
  final double imageH = swap ? imageSize.width : imageSize.height;

  final sx = widgetSize.width / imageW;
  final sy = widgetSize.height / imageH;
  final scale = sx > sy ? sx : sy;

  final scaledW = imageW * scale;
  final scaledH = imageH * scale;
  final dx = (widgetSize.width - scaledW) / 2;
  final dy = (widgetSize.height - scaledH) / 2;

  double left = r.left * scale + dx;
  double top = r.top * scale + dy;
  double right = r.right * scale + dx;
  double bottom = r.bottom * scale + dy;

  if (mirror) {
    final w = widgetSize.width;
    final newLeft = w - right;
    final newRight = w - left;
    left = newLeft;
    right = newRight;
  }

  return Rect.fromLTRB(left, top, right, bottom);
}

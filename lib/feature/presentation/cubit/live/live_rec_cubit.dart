import 'dart:async';
import 'package:face_recognition_app/core/service/face_ml/detection_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image/image.dart' as img;
import '../../../../core/service/face_ml/face_ml_service.dart';
import '../../../../core/service/descriptor/descriptor_service.dart';
import '../../../data/repositories/face_rec_repository.dart';
import '../../../../core/database/app_database.dart' show appDb;
import 'live_rec_state.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../../data/models/recognized_face.dart';

class LiveRecCubit extends Cubit<LiveRecState> {
  late final FaceMlService _ml;
  late final DescriptorService _desc;
  late final FaceRecRepository _repo;

  StreamSubscription? _sub;
  bool _busy = false;
  DateTime _lastRun = DateTime.fromMillisecondsSinceEpoch(0);

  final Map<String, _Lock> _locks = {};
  final int graceMs = 3000;
  final int maxMisses = 5;
  double get enterThresh => state.minCosine;
  double get exitThresh => state.minCosine - 0.08;

  LiveRecCubit() : super(const LiveRecState()) {
    _ml = FaceMlService();
    _desc = DescriptorService();
    _repo = FaceRecRepository(db: appDb, ml: _ml, desc: _desc);
  }

  Future<void> initCamera() async {
    try {
      await _ml.start();
      emit(state.copyWith(
        camera: _ml.controller,
        cameraReady: true,
        clearError: true,
        lastRotation: _ml.lastRotation,
      ));
      _listenStream();
    } catch (e) {
      emit(state.copyWith(error: 'Failed to start camera: $e', cameraReady: false));
    }
  }

  void _listenStream() {
    _sub?.cancel();
    _sub = _ml.results?.listen((det) async {
      if (det.faces.isEmpty) {
        _updateLocksOnEmpty();
        _emitWithLocked([], det);
        return;
      }

      final now = DateTime.now();
      if (_busy || now.difference(_lastRun).inMilliseconds < 350) return;
      _busy = true;
      _lastRun = now;

      try {
        final frameImg = _ml.getLatestFrameImage();
        if (frameImg == null) {
          _busy = false;
          return;
        }

        final rawMatches = await _repo.recognizeFromDecodedAndFaces(
          frameImg,
          det.faces,
          minCosine: enterThresh,
          margin: 0.05,
        );

        final lockedMatches = <RecognizedFace>[];
        for (final f in det.faces) {
          final key = _faceKey(f);
          final best = _bestForFace(f.boundingBox, rawMatches);
          final now = DateTime.now();
          final lock = _locks[key];

          if (best != null && best.score >= enterThresh) {
            _locks[key] = _Lock(
              name: best.name,
              userId: best.userId,
              score: best.score,
              lastSeen: now,
              misses: 0,
              box: best.box,
            );
            lockedMatches.add(best);
            continue;
          }

          if (lock != null) {
            final age = now.difference(lock.lastSeen).inMilliseconds;
            if (age < graceMs && lock.misses < maxMisses) {
              _locks[key] = lock.copyWith(
                misses: lock.misses + 1,
                box: f.boundingBox,
              );
              lockedMatches.add(RecognizedFace(
                userId: lock.userId,
                name: lock.name,
                score: lock.score,
                box: f.boundingBox,
              ));
            } else {
              _locks.remove(key);
            }
          }
        }

        final seenKeys = det.faces.map(_faceKey).toSet();
        final toRemove = <String>[];
        _locks.forEach((k, v) {
          if (!seenKeys.contains(k)) {
            final age = DateTime.now().difference(v.lastSeen).inMilliseconds;
            if (age >= graceMs || v.misses >= maxMisses) {
              toRemove.add(k);
            } else {
              _locks[k] = v.copyWith(misses: v.misses + 1);
            }
          }
        });
        for (final k in toRemove) {
          _locks.remove(k);
        }

        _emitWithLocked(lockedMatches, det);
      } catch (e) {
        emit(state.copyWith(error: 'Live recognition failed: $e'));
      } finally {
        _busy = false;
      }
    });
  }

  void _updateLocksOnEmpty() {
    final now = DateTime.now();
    final toRemove = <String>[];
    _locks.forEach((k, v) {
      final age = now.difference(v.lastSeen).inMilliseconds;
      if (age >= graceMs || v.misses >= maxMisses) {
        toRemove.add(k);
      } else {
        _locks[k] = v.copyWith(misses: v.misses + 1);
      }
    });
    for (final k in toRemove) {
      _locks.remove(k);
    }
  }

  void _emitWithLocked(List<RecognizedFace> locked, DetectionResult det) {
    emit(state.copyWith(
      faces: det.faces,
      imageSize: Size(det.imageSize.width, det.imageSize.height),
      matches: locked,
      lastRotation: _ml.lastRotation,
    ));
  }

  RecognizedFace? _bestForFace(Rect r, List<RecognizedFace> all) {
    RecognizedFace? best;
    double bestIou = 0;
    for (final m in all) {
      final i = _iou(r, m.box);
      if (i > bestIou) {
        bestIou = i;
        best = m;
      }
    }
    if (best == null) return null;
    if (best.score >= enterThresh) return best;
    if (best.score >= exitThresh) return best;
    return null;
  }

  String _faceKey(Face f) {
    final id = f.trackingId;
    if (id != null) return 'tid:$id';
    final b = f.boundingBox;
    return 'bb:${b.left.toStringAsFixed(1)}:${b.top.toStringAsFixed(1)}:${b.right.toStringAsFixed(1)}:${b.bottom.toStringAsFixed(1)}';
    }

  double _iou(Rect a, Rect b) {
    final left = a.left > b.left ? a.left : b.left;
    final top = a.top > b.top ? a.top : b.top;
    final right = a.right < b.right ? a.right : b.right;
    final bottom = a.bottom < b.bottom ? a.bottom : b.bottom;
    final interW = (right - left);
    final interH = (bottom - top);
    final inter = (interW <= 0 || interH <= 0) ? 0.0 : interW * interH;
    final union = a.width * a.height + b.width * b.height - inter;
    return union > 0 ? inter / union : 0.0;
  }

  Future<void> disposeCamera() async {
    await _sub?.cancel();
    try { await _ml.stop(); } catch (_) {}
  }
}

class _Lock {
  final String name;
  final int userId;
  final double score;
  final DateTime lastSeen;
  final int misses;
  final Rect box;

  _Lock({
    required this.name,
    required this.userId,
    required this.score,
    required this.lastSeen,
    required this.misses,
    required this.box,
  });

  _Lock copyWith({
    String? name,
    int? userId,
    double? score,
    DateTime? lastSeen,
    int? misses,
    Rect? box,
  }) {
    return _Lock(
      name: name ?? this.name,
      userId: userId ?? this.userId,
      score: score ?? this.score,
      lastSeen: lastSeen ?? this.lastSeen,
      misses: misses ?? this.misses,
      box: box ?? this.box,
    );
  }
}

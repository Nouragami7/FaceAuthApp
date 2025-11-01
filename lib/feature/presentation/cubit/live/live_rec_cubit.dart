import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/service/face_ml/face_ml_service.dart';
import '../../../../core/service/descriptor/descriptor_service.dart';
import '../../../data/repositories/face_rec_repository.dart';
import '../../../../core/database/app_database.dart' show appDb;
import 'live_rec_state.dart';

class LiveRecCubit extends Cubit<LiveRecState> {
  late final FaceMlService _ml;
  late final DescriptorService _desc;
  late final FaceRecRepository _repo;

  StreamSubscription? _sub;
  bool _busy = false;
  DateTime _lastRun = DateTime.fromMillisecondsSinceEpoch(0);

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
        emit(state.copyWith(faces: const [], imageSize: null, matches: const []));
        return;
      }

      final now = DateTime.now();
      if (_busy || now.difference(_lastRun).inMilliseconds < 400) return;
      _busy = true;
      _lastRun = now;

      try {
        final frameImg = _ml.getLatestFrameImage();
        if (frameImg == null) return;

        final matches = await _repo.recognizeFromDecodedAndFaces(
          frameImg,
          det.faces,
          minCosine: state.minCosine,
        );

        emit(state.copyWith(
          faces: det.faces,
          imageSize: Size(det.imageSize.width, det.imageSize.height),
          matches: matches,
          lastRotation: _ml.lastRotation,
        ));
      } catch (e) {
        emit(state.copyWith(error: 'Live recognition failed: $e'));
      } finally {
        _busy = false;
      }
    });
  }

  Future<void> disposeCamera() async {
    await _sub?.cancel();
    try { await _ml.stop(); } catch (_) {}
  }
}

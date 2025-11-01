import 'dart:typed_data';
import 'package:face_recognition_app/feature/data/repositories/face_rec_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image/image.dart' as img;
import 'package:camera/camera.dart';
import '../../../../../core/database/app_database.dart';
import '../../../../../core/service/face_ml/face_ml_service.dart';
import '../../../../../core/service/descriptor/descriptor_service.dart';
import 'enroll_state.dart';

class EnrollCubit extends Cubit<EnrollState> {
  final AppDatabase db;
  late final FaceMlService _ml;
  late final DescriptorService _desc;
  late final FaceRecRepository _repo;

  EnrollCubit(this.db) : super(const EnrollState()) {
    _ml = FaceMlService();
    _desc = DescriptorService();
    _repo = FaceRecRepository(db: db, ml: _ml, desc: _desc);
  }

  Future<void> initCamera() async {
    try {
      await _ml.start();
      emit(state.copyWith(camera: _ml.controller, cameraReady: true, clearError: true));
    } catch (e) {
      emit(state.copyWith(error: 'Failed to start camera: $e', cameraReady: false));
    }
  }

  Future<void> captureFace() async {
    if (state.camera == null || state.isCapturing) return;
    if (state.faces.length >= 5) {
      emit(state.copyWith(message: 'You already captured 5 faces.'));
      return;
    }
    emit(state.copyWith(isCapturing: true, clearMessage: true));
    try {
      final pic = await state.camera!.takePicture();
      final bytes = await pic.readAsBytes();
      final faces = await _ml.detectFacesFromBytes(bytes);
      if (faces.isEmpty) {
        emit(state.copyWith(message: 'No face detected.', isCapturing: false));
        return;
      }
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        emit(state.copyWith(error: 'Failed to decode image.', isCapturing: false));
        return;
      }
      final crop = _ml.cropToFace(decoded, faces.first, padding: 0.2);
      final updated = List<img.Image>.from(state.faces)..add(crop);
      emit(state.copyWith(faces: updated, isCapturing: false, message: 'Captured ${updated.length}/5'));
    } catch (e) {
      emit(state.copyWith(error: 'Capture failed: $e', isCapturing: false));
    }
  }

  Future<int?> saveUser({required int userId, required String name}) async {
    emit(state.copyWith(isSaving: true, clearError: true, clearMessage: true));
    try {
      final id = await _repo.enrollFromFaceImages(userId: userId, name: name, faceImages: state.faces);
      emit(state.copyWith(isSaving: false, faces: const [], message: 'Saved successfully (id=$id)'));
      return id;
    } catch (e) {
      emit(state.copyWith(isSaving: false, error: 'Save failed: $e'));
      return null;
    }
  }

  Future<void> disposeCamera() async {
    try {
      await _ml.stop();
    } catch (_) {}
  }
}


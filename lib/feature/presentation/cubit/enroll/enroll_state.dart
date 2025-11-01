import 'package:camera/camera.dart';
import 'package:equatable/equatable.dart';
import 'package:image/image.dart' as img;

class EnrollState extends Equatable {
  final CameraController? camera;
  final bool cameraReady;
  final bool isCapturing;
  final bool isSaving;
  final List<img.Image> faces;
  final String? error;
  final String? message;

  const EnrollState({
    this.camera,
    this.cameraReady = false,
    this.isCapturing = false,
    this.isSaving = false,
    this.faces = const [],
    this.error,
    this.message,
  });

  EnrollState copyWith({
    CameraController? camera,
    bool? cameraReady,
    bool? isCapturing,
    bool? isSaving,
    List<img.Image>? faces,
    String? error,
    String? message,
    bool clearMessage = false,
    bool clearError = false,
  }) {
    return EnrollState(
      camera: camera ?? this.camera,
      cameraReady: cameraReady ?? this.cameraReady,
      isCapturing: isCapturing ?? this.isCapturing,
      isSaving: isSaving ?? this.isSaving,
      faces: faces ?? this.faces,
      error: clearError ? null : (error ?? this.error),
      message: clearMessage ? null : (message ?? this.message),
    );
  }

  @override
  List<Object?> get props => [camera, cameraReady, isCapturing, isSaving, faces, error, message];
}


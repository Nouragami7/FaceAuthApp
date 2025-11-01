import 'package:camera/camera.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../../data/models/recognized_face.dart';

class LiveRecState extends Equatable {
  final CameraController? camera;
  final bool cameraReady;
  final List<Face> faces;
  final Size? imageSize;
  final List<RecognizedFace> matches;
  final InputImageRotation? lastRotation;
  final String? error;
  final double minCosine;

  const LiveRecState({
    this.camera,
    this.cameraReady = false,
    this.faces = const [],
    this.imageSize,
    this.matches = const [],
    this.lastRotation,
    this.error,
    this.minCosine = 0.68,
  });

  LiveRecState copyWith({
    CameraController? camera,
    bool? cameraReady,
    List<Face>? faces,
    Size? imageSize,
    List<RecognizedFace>? matches,
    InputImageRotation? lastRotation,
    String? error,
    double? minCosine,
    bool clearError = false,
  }) {
    return LiveRecState(
      camera: camera ?? this.camera,
      cameraReady: cameraReady ?? this.cameraReady,
      faces: faces ?? this.faces,
      imageSize: imageSize ?? this.imageSize,
      matches: matches ?? this.matches,
      lastRotation: lastRotation ?? this.lastRotation,
      error: clearError ? null : (error ?? this.error),
      minCosine: minCosine ?? this.minCosine,
    );
  }

  @override
  List<Object?> get props =>
      [camera, cameraReady, faces, imageSize, matches, lastRotation, error, minCosine];
}

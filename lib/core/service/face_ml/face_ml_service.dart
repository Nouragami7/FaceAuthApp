import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'detection_result.dart';
import 'fps_counter.dart';
import 'nv21_converter.dart';
import 'rotation_helper.dart';

class FaceMlService {
  CameraController? _controller;
  late final FaceDetector _detector;
  InputImageRotation? lastRotation;
  bool _isProcessing = false;
  StreamController<DetectionResult>? _resultCtrl;
  final FpsCounter _fps = FpsCounter();
  Uint8List? _lastNv21;
  InputImageMetadata? _lastMeta;

  FaceMlService() {
    final options = FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableContours: true,
      enableLandmarks: false,
      enableTracking: true,
      minFaceSize: 0.10,
    );
    _detector = FaceDetector(options: options);
    debugPrint('[FaceRec][Init] FaceDetector FAST + contours, minFace=0.10');
  }

  CameraController? get controller => _controller;
  Stream<DetectionResult>? get results => _resultCtrl?.stream;

  (Uint8List nv21, InputImageMetadata meta)? get latestNv21Frame {
    final a = _lastNv21, b = _lastMeta;
    if (a == null || b == null) return null;
    return (Uint8List.fromList(a), b);
  }

  img.Image? getLatestFrameImage() {
    return Nv21Converter.latestNv21ToImage(latestNv21Frame);
  }

  Future<void> start() async {
    debugPrint('[FaceRec][Start] Requesting cameras…');
    try {
      final cams = await availableCameras();
      debugPrint(
        '[FaceRec][Start] Found ${cams.length} cameras: ${cams.map((c) => '${c.name}/${c.lensDirection}/${c.sensorOrientation}').join(', ')}',
      );
      if (cams.isEmpty) throw 'No cameras reported by device';
      final cam = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      debugPrint(
        '[FaceRec][Start] Selected camera: ${cam.name} | lens=${cam.lensDirection} | sensorOri=${cam.sensorOrientation}',
      );
      _controller = CameraController(
        cam,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await _controller!.initialize();
      final v = _controller!.value;
      debugPrint(
        '[FaceRec][Start] Camera initialized. previewSize=${v.previewSize}',
      );
      try {
        final minZ = await _controller!.getMinZoomLevel();
        await _controller!.setZoomLevel(minZ);
        debugPrint('[FaceRec][Start] Zoom set to $minZ (widest).');
      } catch (e) {
        debugPrint('[FaceRec][Start][WARN] setZoom failed: $e');
      }
      await _resultCtrl?.close();
      _resultCtrl = StreamController.broadcast();
      _fps.reset();
      await _controller!.startImageStream(_onFrame);
      debugPrint('[FaceRec][Start] Image stream started ✓');
    } catch (e, st) {
      debugPrint('[FaceRec][Start][ERROR] $e');
      debugPrint('$st');
      rethrow;
    }
  }

  Future<void> stop() async {
    debugPrint('[FaceRec][Stop] Stopping…');
    try {
      if (_controller?.value.isStreamingImages == true) {
        await _controller?.stopImageStream();
        debugPrint('[FaceRec][Stop] Image stream stopped');
      }
      await _controller?.dispose();
      _controller = null;
      await _detector.close();
      await _resultCtrl?.close();
      _resultCtrl = null;
      _lastNv21 = null;
      _lastMeta = null;
      debugPrint('[FaceRec][Stop] Detector closed & resources released');
    } catch (e, st) {
      debugPrint('[FaceRec][Stop][ERROR] $e');
      debugPrint('$st');
    }
  }

  Future<List<Face>> detectFacesFromBytes(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final f = File(
      '${dir.path}/mlkit_input_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await f.writeAsBytes(bytes, flush: true);
    final input = InputImage.fromFilePath(f.path);
    final faces = await _detector.processImage(input);
    try {
      await f.delete();
    } catch (_) {}
    return faces;
  }

  img.Image cropToFace(img.Image decoded, Face face, {double padding = 0.20}) {
    final bb = face.boundingBox;
    final w = decoded.width.toDouble();
    final h = decoded.height.toDouble();
    final padX = bb.width * padding;
    final padY = bb.height * padding;
    final left = (bb.left - padX).floor().clamp(0, w.toInt());
    final top = (bb.top - padY).floor().clamp(0, h.toInt());
    final right = (bb.right + padX).ceil().clamp(0, w.toInt());
    final bottom = (bb.bottom + padY).ceil().clamp(0, h.toInt());
    final cw = (right - left) <= 0 ? 1 : right - left;
    final ch = (bottom - top) <= 0 ? 1 : bottom - top;
    return img.copyCrop(decoded, left, top, cw, ch);
  }

  void _onFrame(CameraImage image) async {
    _fps.onFrame(tag: 'FaceRec[FPS]');
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      final ctrl = _controller;
      if (ctrl == null || !ctrl.value.isInitialized) {
        _isProcessing = false;
        return;
      }
      final rotation = RotationHelper.fromSensorOrientation(
        ctrl.description.sensorOrientation,
      );
      lastRotation = rotation;
      Uint8List bytes;
      InputImageFormat format;
      int bytesPerRow;
      final planes = image.planes;
      if (planes.isEmpty) {
        _isProcessing = false;
        return;
      }
      if (planes.length == 1) {
        final p0 = planes[0];
        bytes = p0.bytes;
        format = InputImageFormat.bgra8888;
        bytesPerRow = p0.bytesPerRow;
        _lastNv21 = null;
        _lastMeta = null;
      } else if (planes.length == 3) {
        bytes = Nv21Converter.yuv420ToNv21(image);
        format = InputImageFormat.nv21;
        bytesPerRow = planes[0].bytesPerRow;
        final metaTmp = InputImageMetadata(
          size: ui.Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: bytesPerRow,
        );
        _lastNv21 = bytes;
        _lastMeta = metaTmp;
      } else {
        debugPrint(
          '[FaceRec][Frame][WARN] Unsupported planes=${planes.length}',
        );
        _isProcessing = false;
        return;
      }
      final meta = InputImageMetadata(
        size: ui.Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: (planes.isNotEmpty) ? planes[0].bytesPerRow : bytes.length,
      );
      final input = InputImage.fromBytes(bytes: bytes, metadata: meta);
      final swDetect = Stopwatch()..start();
      final faces = await _detector.processImage(input);
      swDetect.stop();
      debugPrint(
        '[FaceRec][Frame] w=${image.width}, h=${image.height}, rot=$rotation, planes=${planes.length}, format=$format, detect=${swDetect.elapsedMilliseconds}ms, faces=${faces.length}',
      );
      if (faces.isNotEmpty) {
        final bb = faces.first.boundingBox;
        debugPrint(
          '[FaceRec][Face] bb=[${bb.left.toStringAsFixed(1)},${bb.top.toStringAsFixed(1)} → ${bb.right.toStringAsFixed(1)},${bb.bottom.toStringAsFixed(1)}] size=${bb.width.toStringAsFixed(1)}x${bb.height.toStringAsFixed(1)}',
        );
      }
      _resultCtrl?.add(
        DetectionResult(
          faces: faces,
          imageSize: meta.size,
          imageRotation: rotation,
        ),
      );
    } catch (e, st) {
      debugPrint('[FaceRec][OnFrame][ERROR] $e');
      debugPrint('$st');
    } finally {
      _isProcessing = false;
    }
  }
}

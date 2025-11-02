import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../../../core/service/face_ml/face_ml_service.dart';

class FullscreenCapturePage extends StatefulWidget {
  const FullscreenCapturePage({super.key});
  @override
  State<FullscreenCapturePage> createState() => _FullscreenCapturePageState();
}

class _FullscreenCapturePageState extends State<FullscreenCapturePage> {
  final FaceMlService _ml = FaceMlService();
  final List<img.Image> _faces = [];
  bool _busy = false;
  bool _ready = false;
  static const int _target = 5;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _ml.start();
    setState(() => _ready = true);
  }

  @override
  void dispose() {
    _ml.stop();
    super.dispose();
  }

 Future<void> _capture() async {
  if (!_ready || _busy) return;
  if (_faces.length >= _target) return;
  setState(() => _busy = true);
  try {
    final cam = _ml.controller;
    if (cam == null) { setState(() => _busy = false); return; }

    final pic = await cam.takePicture();
    final bytes = await pic.readAsBytes();
    final faces = await _ml.detectFacesFromBytes(bytes);
    if (faces.isEmpty) {
      setState(() => _busy = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No face detected — please face the camera clearly.'), duration: Duration(seconds: 2)),
        );
      }
      return;
    }

    final raw = img.decodeImage(bytes);
    if (raw == null) { setState(() => _busy = false); return; }

    final baked = img.bakeOrientation(raw);
    final upright = baked.height > baked.width ? img.copyRotate(baked, 90) : baked;

    faces.sort((a, b) {
      final sa = a.boundingBox.width * a.boundingBox.height;
      final sb = b.boundingBox.width * b.boundingBox.height;
      return sb.compareTo(sa);
    });
    final f = faces.first;

    final frameW = upright.width.toDouble();
    final frameH = upright.height.toDouble();
    final areaRatio = (f.boundingBox.width * f.boundingBox.height) / (frameW * frameH);
    final yaw = (f.headEulerAngleY ?? 0).abs();
    final roll = (f.headEulerAngleZ ?? 0).abs();

    if (areaRatio < 0.18 || yaw > 20 || roll > 20) {
      setState(() => _busy = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Center your face and move a bit closer.'), duration: Duration(seconds: 2)),
        );
      }
      return;
    }

    double mean = 0;
    for (int y = 0; y < upright.height; y++) {
      for (int x = 0; x < upright.width; x++) {
        final c = upright.getPixel(x, y);
        mean += (0.299 * img.getRed(c) + 0.587 * img.getGreen(c) + 0.114 * img.getBlue(c));
      }
    }
    mean /= (upright.width * upright.height);
    if (mean < 30 || mean > 235) {
      setState(() => _busy = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Adjust lighting and try again.'), duration: Duration(seconds: 2)),
        );
      }
      return;
    }

    final crop = _ml.cropToFace(upright, f, padding: 0.28);
    final sq = img.copyResizeCropSquare(crop, 128);
    final g = img.grayscale(sq);

    double varLap = 0;
    final w = g.width, h = g.height;
    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        final gc = img.getRed(g.getPixel(x, y));
        final gl = img.getRed(g.getPixel(x - 1, y));
        final gr = img.getRed(g.getPixel(x + 1, y));
        final gu = img.getRed(g.getPixel(x, y - 1));
        final gd = img.getRed(g.getPixel(x, y + 1));
        final lap = 4 * gc - gl - gr - gu - gd;
        varLap += lap * lap;
      }
    }
    varLap /= ((w - 2) * (h - 2));

    if (varLap < 120) {
      setState(() => _busy = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image is blurry — hold still and try again.'), duration: Duration(seconds: 2)),
        );
      }
      return;
    }



    setState(() {
      _faces.add(crop);
      _busy = false;
    });
  } catch (_) {
    setState(() => _busy = false);
  }
}




  void _done() {
    if (_faces.length < _target) return;
    Navigator.pop(context, _faces);
  }

  Future<bool> _onWillPop() async {
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final cam = _ml.controller;
    final canFinish = _faces.length >= _target;
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text('${_faces.length}/$_target'),
          automaticallyImplyLeading: true,
        ),
        body: SafeArea(
          child: Stack(
            children: [
              if (cam != null && _ready)
                Positioned.fill(child: CameraPreview(cam)),
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _busy ? null : _capture,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: Text(
                          _busy
                              ? 'Capturing...'
                              : 'Capture ${_faces.length}/$_target',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: canFinish ? _done : null,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

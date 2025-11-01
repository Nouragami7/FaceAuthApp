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
      if (cam == null) {
        setState(() => _busy = false);
        return;
      }
      final pic = await cam.takePicture();
      final bytes = await pic.readAsBytes();
      final faces = await _ml.detectFacesFromBytes(bytes);
      if (faces.isEmpty) {
        setState(() => _busy = false);
        return;
      }
      final raw = img.decodeImage(bytes);
      if (raw == null) {
        setState(() => _busy = false);
        return;
      }
      final baked = img.bakeOrientation(raw);
      final upright = baked.height > baked.width ? img.copyRotate(baked, 90) : baked;
      faces.sort((a,b){
        final sa = a.boundingBox.width * a.boundingBox.height;
        final sb = b.boundingBox.width * b.boundingBox.height;
        return sb.compareTo(sa);
      });
      final crop = _ml.cropToFace(upright, faces.first, padding: 0.28);
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
    return _faces.length >= _target;
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
              if (cam != null && _ready) Positioned.fill(child: CameraPreview(cam)),
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _busy ? null : _capture,
                        child: Text(_busy ? 'Capturing...' : 'Capture ${_faces.length}/$_target'),
                        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: canFinish ? _done : null,
                        child: const Text('Done'),
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
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

import 'dart:typed_data';
import 'package:camera/camera.dart' show CameraPreview;
import 'package:face_recognition_app/feature/presentation/cubit/enroll/enroll_cubit.dart';
import 'package:face_recognition_app/feature/presentation/cubit/enroll/enroll_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image/image.dart' as img;
import 'package:face_recognition_app/core/utils/validators.dart';

class EnrollPage extends StatefulWidget {
  const EnrollPage({super.key});

  @override
  State<EnrollPage> createState() => _EnrollPageState();
}

class _EnrollPageState extends State<EnrollPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _idCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<EnrollCubit>().initCamera();
  }

  @override
  void dispose() {
    context.read<EnrollCubit>().disposeCamera();
    _nameCtrl.dispose();
    _idCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = int.parse(_idCtrl.text.trim());
    final name = _nameCtrl.text.trim();
    final facesCount = context.read<EnrollCubit>().state.faces.length;
    if (facesCount < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture 5 face images first')),
      );
      return;
    }
    final id = await context.read<EnrollCubit>().saveUser(
      userId: userId,
      name: name,
    );
    if (!mounted) return;
    if (id != null) {
      _formKey.currentState!.reset();
      _nameCtrl.clear();
      _idCtrl.clear();
    }
    if (id != null && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('Enroll New Face')),
      resizeToAvoidBottomInset: true,
      body: BlocConsumer<EnrollCubit, EnrollState>(
        listener: (context, state) {
          if (state.message != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message!)));
          }
          if (state.error != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.error!)));
          }
        },
        builder: (context, state) {
          final cam = state.camera;
          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: keyboardInset > 0 ? keyboardInset + 12 : 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: screenH * 0.6,
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.black12,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child:
                          cam == null || !state.cameraReady
                              ? const Center(child: CircularProgressIndicator())
                              : CameraPreview(cam),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _idCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'User ID',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: Validators.id,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _nameCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'User Name',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: Validators.name,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed:
                                      state.isCapturing
                                          ? null
                                          : () =>
                                              context
                                                  .read<EnrollCubit>()
                                                  .captureFace(),
                                  icon: const Icon(Icons.camera_alt),
                                  label: const Text('Capture'),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: state.isSaving ? null : _onSave,
                                  icon: const Icon(Icons.save),
                                  label:
                                      state.isSaving
                                          ? const Text('Saving...')
                                          : const Text('Save'),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Captured: ${state.faces.length}/5'),
                          ),
                          if (state.faces.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 84,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: state.faces.length,
                                separatorBuilder:
                                    (_, __) => const SizedBox(width: 8),
                                itemBuilder: (_, i) {
                                  final face = state.faces[i];
                                  final faceBytes = Uint8List.fromList(
                                    img.encodeJpg(face),
                                  );
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      faceBytes,
                                      height: 80,
                                      width: 80,
                                      fit: BoxFit.cover,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

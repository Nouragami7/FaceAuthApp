import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image/image.dart' as img;
import 'package:face_recognition_app/core/utils/validators.dart';
import 'package:face_recognition_app/config/route/routes.dart';
import 'package:face_recognition_app/feature/presentation/cubit/enroll/enroll_cubit.dart';
import 'package:face_recognition_app/feature/presentation/cubit/enroll/enroll_state.dart';

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
  void dispose() {
    _nameCtrl.dispose();
    _idCtrl.dispose();
    super.dispose();
  }

  Future<void> _openCapture() async {
    final res = await Navigator.pushNamed(context, AppRoutes.capture);
    if (!mounted) return;
    if (res is List<img.Image> && res.isNotEmpty) {
      context.read<EnrollCubit>().setFaces(res);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Captured ${res.length}')));
    }
  }

 Future<void> _onSave() async {
  if (!_formKey.currentState!.validate()) return;

  final userId = int.parse(_idCtrl.text.trim());
  final name = _nameCtrl.text.trim();
  final facesCount = context.read<EnrollCubit>().state.faces.length;

  final db = context.read<EnrollCubit>().db;
  final existing = await db.getAllUsers();
  final exists = existing.any((u) => u.id == userId);

  if (exists) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('User ID $userId already exists — please use another ID.')),
    );
    return;
  }

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
    Navigator.pop(context, true);
  }
}


  @override
  Widget build(BuildContext context) {
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
          return SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: keyboardInset > 0 ? keyboardInset + 12 : 12,
                top: 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _idCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'User ID',
                            border: OutlineInputBorder(),
                          ),
                          validator: Validators.id,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'User Name',
                            border: OutlineInputBorder(),
                          ),
                          validator: Validators.name,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.indigo.withOpacity(0.18),
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enrollment Tips',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text('• Take exactly 5 clear face photos.'),
                        SizedBox(height: 2),
                        Text(
                          '• Keep the camera at a suitable distance (~30–40 cm).',
                        ),
                        SizedBox(height: 2),
                        Text(
                          '• Center your face, look straight, and ensure good lighting.',
                        ),
                        SizedBox(height: 2),
                        Text(
                          '• Avoid extreme angles, occlusions, or heavy motion.',
                        ),
                        SizedBox(height: 2),
                        Text('• These improve recognition accuracy later.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _openCapture,
                    icon: const Icon(Icons.photo_camera, size: 22),
                    label: const Text('Open Fullscreen Camera'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Captured: ${state.faces.length}/5',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (state.faces.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: state.faces.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final face = state.faces[i];
                          final faceBytes = Uint8List.fromList(
                            img.encodeJpg(face),
                          );
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              faceBytes,
                              height: 86,
                              width: 86,
                              fit: BoxFit.cover,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _onSave,
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
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

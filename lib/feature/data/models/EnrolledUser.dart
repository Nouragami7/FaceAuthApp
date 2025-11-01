import 'dart:typed_data';

class EnrolledUser {
  final String userId;
  final String name;
  final Uint8List faceJpg;
  final Uint8List embedding;

  EnrolledUser({
    required this.userId,
    required this.name,
    required this.faceJpg,
    required this.embedding,
  });
}
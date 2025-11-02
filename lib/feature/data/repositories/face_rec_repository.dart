import 'dart:math' as math;
import 'dart:typed_data';

import 'package:face_recognition_app/core/service/descriptor/descriptor_service.dart';
import 'package:face_recognition_app/core/service/face_ml/face_ml_service.dart';
import 'package:face_recognition_app/core/utils/cosine_similarity.dart';
import 'package:face_recognition_app/core/utils/image_rotate_compat.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

import '../../../core/database/app_database.dart';
import '../models/recognized_face.dart';
import '../models/user_vecs.dart';

class FaceRecRepository {
  final AppDatabase db;
  final FaceMlService ml;
  final DescriptorService desc;

  FaceRecRepository({required this.db, required this.ml, required this.desc});

  Future<int?> enrollFromFaceImages({
    required int userId,
    required String name,
    required List<img.Image> faceImages,
  }) async {
    if (faceImages.isEmpty) {
      return null;
    }
    try {
      final upsertedId = await db.insertUser(customId: userId, name: name);
      for (int i = 0; i < faceImages.length; i++) {
        final fi = faceImages[i];
        final vec = desc.imageToDescriptor(fi);
        final bytes = desc.float32ListToBytes(vec);
        double l2 = 0.0;
        for (final v in vec) {
          l2 += v * v;
        }
        l2 = math.sqrt(l2);
        await db.insertVector(
          userId: upsertedId,
          dims: vec.length,
          vectorBytes: bytes,
          l2norm: l2,
        );
      }
      if (faceImages.isNotEmpty) {
        final last = faceImages.last;
        final landscape =
            (last.height > last.width) ? rotate90Compat(last, times: 1) : last;
        final avatarJpg = img.encodeJpg(landscape, quality: 85);
        await db.updateUserAvatarBytes(
          upsertedId,
          Uint8List.fromList(avatarJpg),
        );
      }
      return upsertedId;
    } catch (_) {
      return null;
    }
  }

  Future<void> updateUserAvatarFromImage(int userId, img.Image image) async {
    final avatarJpg = img.encodeJpg(image, quality: 85);
    await db.updateUserAvatarBytes(userId, Uint8List.fromList(avatarJpg));
  }

  double _scoreUserTopKMean(
    Float32List probe,
    List<Float32List> vecs, {
    int k = 3,
  }) {
    if (vecs.isEmpty) return -1;
    final sims = <double>[];
    for (final v in vecs) {
      sims.add(cosineSimilarity(probe, v));
    }
    sims.sort((a, b) => b.compareTo(a));
    final take = sims.length < k ? sims.length : k;
    double sum = 0;
    for (int i = 0; i < take; i++) {
      sum += sims[i];
    }
    return sum / take;
  }

  Future<List<RecognizedFace>> recognizeFromImageBytes(
    Uint8List imageBytes, {
    double minCosine = 0.85,
    double margin = 0.05,
  }) async {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      return [];
    }
    final faces = await ml.detectFacesFromBytes(imageBytes);
    if (faces.isEmpty) return [];
    final rows = await db.getAllUserVectors();
    if (rows.isEmpty) return [];

    final Map<int, UserVecs> gallery = {};
    final expectedDims = desc.size * desc.size;

    for (final r in rows) {
      if (r.vector.dims != expectedDims) continue;

      final u8 = r.vector.vector;
      final vec = u8.buffer.asFloat32List(
        u8.offsetInBytes,
        u8.lengthInBytes ~/ 4,
      );
      gallery
          .putIfAbsent(r.user.id, () => UserVecs(r.user.id, r.user.name, []))
          .vecs
          .add(vec);
    }

    final results = <RecognizedFace>[];
    for (final f in faces) {
      final crop = ml.cropToFace(decoded, f, padding: 0.2);
      final square = img.copyResizeCropSquare(crop, 256);
      final probe = desc.imageToDescriptor(square);

      final perUser = <({int id, String name, double score})>[];
      for (final g in gallery.values) {
        final s = _scoreUserTopKMean(probe, g.vecs, k: 3);
        perUser.add((id: g.userId, name: g.name, score: s));
      }
      perUser.sort((a, b) => b.score.compareTo(a.score));
      if (perUser.isEmpty) continue;

      final best = perUser.first;
      final second = perUser.length > 1 ? perUser[1] : null;

      final pass =
          best.score >= minCosine &&
          (second == null || (best.score - second.score) >= margin);

      if (pass) {
        results.add(
          RecognizedFace(
            userId: best.id,
            name: best.name,
            score: best.score,
            box: f.boundingBox,
          ),
        );
      }
    }
    return results;
  }

  Future<List<RecognizedFace>> recognizeFromDecodedAndFaces(
    img.Image decoded,
    List<Face> faces, {
    double minCosine = 0.68,
    double margin = 0.08,
  }) async {
    if (faces.isEmpty) return [];
    final rows = await db.getAllUserVectors();
    if (rows.isEmpty) return [];

    final Map<int, UserVecs> gallery = {};
    for (final r in rows) {
      final u8 = r.vector.vector;
      final vec = u8.buffer.asFloat32List(
        u8.offsetInBytes,
        u8.lengthInBytes ~/ 4,
      );
      gallery
          .putIfAbsent(r.user.id, () => UserVecs(r.user.id, r.user.name, []))
          .vecs
          .add(vec);
    }

    final results = <RecognizedFace>[];
    for (final f in faces) {
      final crop = ml.cropToFace(decoded, f, padding: 0.2);
      final square = img.copyResizeCropSquare(crop, 256);
      final probe = desc.imageToDescriptor(square);

      final perUser = <({int id, String name, double score})>[];
      for (final g in gallery.values) {
        final s = _scoreUserTopKMean(probe, g.vecs, k: 3);
        perUser.add((id: g.userId, name: g.name, score: s));
      }
      perUser.sort((a, b) => b.score.compareTo(a.score));
      if (perUser.isEmpty) continue;

      final best = perUser.first;
      final second = perUser.length > 1 ? perUser[1] : null;

      final pass =
          best.score >= minCosine &&
          (second == null || (best.score - second.score) >= margin);

      if (pass) {
        results.add(
          RecognizedFace(
            userId: best.id,
            name: best.name,
            score: best.score,
            box: f.boundingBox,
          ),
        );
      }
    }
    return results;
  }

  Future<void> reEnrollUser({
    required int userId,
    required List<img.Image> faceImages,
  }) async {
    if (faceImages.isEmpty) return;
    await db.deleteAllVectorsForUser(userId);
    for (final fi in faceImages) {
      final vec = desc.imageToDescriptor(fi);
      final bytes = desc.float32ListToBytes(vec);
      double l2 = 0.0;
      for (final v in vec) {
        l2 += v * v;
      }
      await db.insertVector(
        userId: userId,
        dims: vec.length,
        vectorBytes: bytes,
        l2norm: math.sqrt(l2),
      );
    }
    final last = faceImages.last;
    final upright =
        (last.width > last.height) ? rotate90Compat(last, times: 1) : last;
    final avatarJpg = img.encodeJpg(upright, quality: 85);
    await db.updateUserAvatarBytes(userId, Uint8List.fromList(avatarJpg));
  }

  Future<void> renameUser(int userId, String newName) =>
      db.updateUserName(userId, newName);
  Future<void> deleteUserCompletely(int userId) => db.deleteUserById(userId);
}

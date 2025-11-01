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
      print('[Repo][Enroll][WARN] empty faceImages');
      return null;
    }
    try {
      print(
        '[Repo][Enroll] id=$userId name="$name" images=${faceImages.length}',
      );
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
        print('[Repo][Enroll] saved vector index=$i for userId=$upsertedId');
      }
      if (faceImages.isNotEmpty) {
        final last = faceImages.last;
        final upright =
            (last.width > last.height) ? rotate90Compat(last, times: 1) : last;
        final avatarJpg = img.encodeJpg(upright, quality: 85);
        await db.updateUserAvatarBytes(
          upsertedId,
          Uint8List.fromList(avatarJpg),
        );
        print(
          '[Repo][Enroll] avatar saved (upright portrait) for userId=$upsertedId',
        );
      }
      print('[Repo][Enroll] completed for userId=$upsertedId');
      return upsertedId;
    } catch (e, st) {
      print('[Repo][Enroll][ERROR] $e');
      print(st);
      return null;
    }
  }

  Future<void> updateUserAvatarFromImage(int userId, img.Image image) async {
    final avatarJpg = img.encodeJpg(image, quality: 85);
    await db.updateUserAvatarBytes(userId, Uint8List.fromList(avatarJpg));
  }

  Future<List<RecognizedFace>> recognizeFromImageBytes(
    Uint8List imageBytes, {
    double minCosine = 0.75,
  }) async {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      print('[Repo][Recognize][ERROR] decodeImage null');
      return [];
    }
    final faces = await ml.detectFacesFromBytes(imageBytes);
    print('[Repo][Recognize] faces=${faces.length}');
    if (faces.isEmpty) return [];
    final rows = await db.getAllUserVectors();
    if (rows.isEmpty) {
      print('[Repo][Recognize] DB empty');
      return [];
    }
    final Map<int, UserVecs> gallery = {};
    for (final r in rows) {
      final user = r.user;
      final fv = r.vector;
      final u8 = fv.vector;
      final vec = u8.buffer.asFloat32List(
        u8.offsetInBytes,
        u8.lengthInBytes ~/ 4,
      );
      gallery
          .putIfAbsent(user.id, () => UserVecs(user.id, user.name, []))
          .vecs
          .add(vec);
    }
    print('[Repo][Recognize] gallery users=${gallery.length}');
    final results = <RecognizedFace>[];
    for (final f in faces) {
      final crop = ml.cropToFace(decoded, f, padding: 0.2);
      final probe = desc.imageToDescriptor(crop);
      String? bestName;
      int? bestUserId;
      double bestScore = -1;
      final scored = <String, double>{};
      for (final g in gallery.values) {
        double userBest = -1;
        for (final v in g.vecs) {
          final s = cosineSimilarity(probe, v);
          if (s > userBest) userBest = s;
        }
        scored[g.name] = userBest;
        if (userBest > bestScore) {
          bestScore = userBest;
          bestName = g.name;
          bestUserId = g.userId;
        }
      }
      final top3 =
          scored.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      print(
        '[Match][Top] ${top3.take(3).map((e) => '${e.key}=${e.value.toStringAsFixed(3)}').join(', ')}',
      );
      if (bestScore >= minCosine && bestName != null && bestUserId != null) {
        results.add(
          RecognizedFace(
            userId: bestUserId,
            name: bestName,
            score: bestScore,
            box: f.boundingBox,
          ),
        );
        print(
          '[Match][Result] MATCH $bestName (${(bestScore * 100).toStringAsFixed(0)}%)',
        );
      } else {
        print('[Match][Result] no match (best=$bestScore)');
      }
    }
    return results;
  }

  Future<List<RecognizedFace>> recognizeFromDecodedAndFaces(
    img.Image decoded,
    List<Face> faces, {
    double minCosine = 0.80,
  }) async {
    print('[Repo][RecognizeDecoded] faces=${faces.length}');
    if (faces.isEmpty) return [];
    final rows = await db.getAllUserVectors();
    if (rows.isEmpty) {
      print('[Repo][RecognizeDecoded] DB empty');
      return [];
    }
    final Map<int, UserVecs> gallery = {};
    for (final r in rows) {
      final user = r.user;
      final fv = r.vector;
      final u8 = fv.vector;
      final vec = u8.buffer.asFloat32List(
        u8.offsetInBytes,
        u8.lengthInBytes ~/ 4,
      );
      gallery
          .putIfAbsent(user.id, () => UserVecs(user.id, user.name, []))
          .vecs
          .add(vec);
    }
    print('[Repo][RecognizeDecoded] gallery users=${gallery.length}');
    final results = <RecognizedFace>[];
    for (final f in faces) {
      final crop = ml.cropToFace(decoded, f, padding: 0.2);
      final probe = desc.imageToDescriptor(crop);
      String? bestName;
      int? bestUserId;
      double bestScore = -1;
      final scored = <String, double>{};
      for (final g in gallery.values) {
        double userBest = -1;
        for (final v in g.vecs) {
          final s = cosineSimilarity(probe, v);
          if (s > userBest) userBest = s;
        }
        scored[g.name] = userBest;
        if (userBest > bestScore) {
          bestScore = userBest;
          bestName = g.name;
          bestUserId = g.userId;
        }
      }
      final top3 =
          scored.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      print(
        '[Match][Top] ${top3.take(3).map((e) => '${e.key}=${e.value.toStringAsFixed(3)}').join(', ')}',
      );
      if (bestScore >= minCosine && bestName != null && bestUserId != null) {
        results.add(
          RecognizedFace(
            userId: bestUserId,
            name: bestName,
            score: bestScore,
            box: f.boundingBox,
          ),
        );
        print(
          '[Match][Result] MATCH $bestName (${(bestScore * 100).toStringAsFixed(0)}%)',
        );
      } else {
        print('[Match][Result] no match (best=$bestScore)');
      }
    }
    return results;
  }

  Future<void> renameUser(int userId, String newName) =>
      db.updateUserName(userId, newName);
  Future<void> deleteUserCompletely(int userId) => db.deleteUserById(userId);
}

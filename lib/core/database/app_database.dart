// lib/core/database/app_database.dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

class Users extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  BlobColumn get avatar => blob().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class FaceVectors extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId =>
      integer().references(Users, #id, onDelete: KeyAction.cascade)();
  IntColumn get dims => integer()();
  BlobColumn get vector => blob()();
  RealColumn get l2norm => real().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'faces.sqlite'));
    print('[DB][Open] Database path: ${file.path}');
    return NativeDatabase(file);
  });
}

@DriftDatabase(tables: [Users, FaceVectors])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.deleteTable('face_vectors');
        await m.deleteTable('users');
        await m.createAll();
        print('[DB][Migrate] Recreated tables for schema v2');
      }

      if (from < 4) {
        await m.addColumn(users, users.avatar);
        print('[DB][Migrate] Added users.avatar (BLOB) at v4');
      }
    },
  );

  Future<int> insertUser({required int customId, required String name}) async {
    print('[DB][InsertUser] inserting id=$customId name="$name"');
    final row = UsersCompanion(id: Value(customId), name: Value(name));
    final id = await into(users).insertOnConflictUpdate(row);
    print('[DB][InsertUser] upserted userId=$id');
    return id;
  }

  Future<int> insertVector({
    required int userId,
    required int dims,
    required Uint8List vectorBytes,
    double? l2norm,
  }) async {
    print(
      '[DB][InsertVector] userId=$userId dims=$dims bytes=${vectorBytes.length}',
    );
    final id = await into(faceVectors).insert(
      FaceVectorsCompanion.insert(
        userId: userId,
        dims: dims,
        vector: vectorBytes,
        l2norm: l2norm == null ? const Value.absent() : Value(l2norm),
      ),
    );
    print('[DB][InsertVector] vectorId=$id');
    return id;
  }

  Future<void> debugPrintUsers() async {
    final all = await select(users).get();
    print('[DB][Users] count=${all.length}');
    for (final u in all) {
      print(
        '   id=${u.id} name=${u.name} avatar=${u.avatar?.length ?? 0} bytes',
      );
    }
  }

  Future<List<({User user, FaceVector vector})>> getAllUserVectors() async {
    print('[DB][Query] Fetching all users + vectors (JOIN)...');
    final query = select(
      users,
    ).join([innerJoin(faceVectors, faceVectors.userId.equalsExp(users.id))]);
    final rows = await query.get();
    print('[DB][Query] got ${rows.length} rows');
    return rows.map((r) {
      final user = r.readTable(users);
      final vector = r.readTable(faceVectors);
      return (user: user, vector: vector);
    }).toList();
  }

  Future<int> countVectorsForUser(int userId) async {
    final countExpr = faceVectors.id.count();
    final q =
        selectOnly(faceVectors)
          ..where(faceVectors.userId.equals(userId))
          ..addColumns([countExpr]);
    final row = await q.getSingle();
    final count = row.read(countExpr) ?? 0;
    print('[DB][Count] userId=$userId vectors=$count');
    return count;
  }

  Future<void> debugPrintAllUserVectors() async {
    final rows =
        await (select(users).join([
          leftOuterJoin(faceVectors, faceVectors.userId.equalsExp(users.id)),
        ])).get();

    final Map<int, (User user, List<FaceVector> vecs)> map = {};
    for (final r in rows) {
      final u = r.readTable(users);
      final v = r.readTableOrNull(faceVectors);
      map.putIfAbsent(u.id, () => (u, <FaceVector>[]));
      if (v != null) map[u.id]!.$2.add(v);
    }

    print('[DB][Dump] Users with vectors: ${map.length}');
    map.forEach((id, pair) {
      print('  userId=$id name=${pair.$1.name} vectors=${pair.$2.length}');
    });
  }

  Future<List<User>> getAllUsers() => select(users).get();

  Stream<List<({User user, int vecCount})>> watchUsersWithCounts() {
    final cnt = faceVectors.id.count();
    final q =
        select(users).join([
            leftOuterJoin(faceVectors, faceVectors.userId.equalsExp(users.id)),
          ])
          ..addColumns([cnt])
          ..groupBy([users.id]);

    return q.watch().map((rows) {
      return rows.map((r) {
        final u = r.readTable(users);
        final c = r.read(cnt) ?? 0;
        return (user: u, vecCount: c);
      }).toList();
    });
  }

  Future<void> updateUserName(int userId, String newName) async {
    await (update(users)..where(
      (u) => u.id.equals(userId),
    )).write(UsersCompanion(name: Value(newName)));
  }

  Future<void> updateUserAvatarBytes(int userId, Uint8List avatarBytes) async {
    await (update(users)..where(
      (u) => u.id.equals(userId),
    )).write(UsersCompanion(avatar: Value(avatarBytes)));
  }

  Future<int> deleteAllVectorsForUser(int userId) {
    return (delete(faceVectors)..where((v) => v.userId.equals(userId))).go();
  }

  Future<void> deleteUserById(int userId) async {
    await (delete(users)..where((u) => u.id.equals(userId))).go();
  }
}

final AppDatabase appDb = AppDatabase();

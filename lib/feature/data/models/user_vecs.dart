import 'dart:typed_data';

class UserVecs {
  final int userId;
  final String name;
  final List<Float32List> vecs;
  UserVecs(this.userId, this.name, this.vecs);
}

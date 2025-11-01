import 'dart:typed_data';
import 'package:equatable/equatable.dart';

class UsersState extends Equatable {
  final bool loading;
  final String? error;
  final List<UserItem> users;

  const UsersState({this.loading = false, this.error, this.users = const []});

  UsersState copyWith({bool? loading, String? error, List<UserItem>? users}) {
    return UsersState(
      loading: loading ?? this.loading,
      error: error,
      users: users ?? this.users,
    );
  }

  @override
  List<Object?> get props => [loading, error, users];
}

class UserItem extends Equatable {
  final int id;
  final String name;
  final Uint8List? avatarBytes;

  const UserItem({required this.id, required this.name, this.avatarBytes});

  @override
  List<Object?> get props => [id, name, avatarBytes];
}

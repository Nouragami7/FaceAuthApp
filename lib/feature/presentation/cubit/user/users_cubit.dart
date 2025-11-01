// lib/feature/presentation/cubit/users_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/database/app_database.dart';
import 'users_state.dart';

class UsersCubit extends Cubit<UsersState> {
  final AppDatabase db;
  UsersCubit(this.db) : super(const UsersState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, error: null));
    try {
      final rows = await db.getAllUsers();
      final items = rows
          .map((u) => UserItem(id: u.id, name: u.name, avatarBytes: u.avatar))
          .toList();
      emit(state.copyWith(loading: false, users: items));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString(), users: []));
    }
  }

  Future<void> rename(int userId, String newName) async {
    try {
      await db.updateUserName(userId, newName);
      await load();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> delete(int userId) async {
    try {
      await db.deleteUserById(userId);
      await load();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}

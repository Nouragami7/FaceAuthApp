import 'package:face_recognition_app/feature/presentation/widgets/dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/database/app_database.dart';
import '../cubit/user/users_cubit.dart';
import '../cubit/user/users_state.dart';
import '../widgets/user_card.dart';
import '../../../config/route/routes.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = RepositoryProvider.of<AppDatabase>(context);
    return BlocProvider(
      create: (_) => UsersCubit(db)..load(),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Face Recognition')),
      body: Column(
        children: [
          Expanded(
            child: BlocBuilder<UsersCubit, UsersState>(
              builder: (context, state) {
                if (state.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.error != null) {
                  return Center(child: Text(state.error!));
                }
                if (state.users.isEmpty) {
                  return const _EmptyUsers();
                }
                return ListView.builder(
                  itemCount: state.users.length,
                  itemBuilder: (context, index) {
                    final u = state.users[index];
                    return UserCard(
                      name: u.name,
                      id: u.id,
                      avatarBytes: u.avatarBytes,
                      onEdit: () async {
                        final newName = await showEditNameDialog(
                          context,
                          currentName: u.name,
                        );
                        if (newName != null && newName.trim().isNotEmpty) {
                          context.read<UsersCubit>().rename(
                            u.id,
                            newName.trim(),
                          );
                        }
                      },
                      onDelete: () async {
                        final confirmed = await showConfirmDeleteDialog(
                          context,
                          name: u.name.isEmpty ? 'User ${u.id}' : u.name,
                        );
                        if (confirmed == true) {
                          context.read<UsersCubit>().delete(u.id);
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
          const _ActionsBar(),
        ],
      ),
    );
  }
}

class _EmptyUsers extends StatelessWidget {
  const _EmptyUsers();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.people_outline, size: 64),
          SizedBox(height: 12),
          Text('No users yet'),
          SizedBox(height: 4),
          Text('Add users using the buttons below'),
        ],
      ),
    );
  }
}

class _ActionsBar extends StatelessWidget {
  const _ActionsBar();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final ok = await Navigator.pushNamed(
                    context,
                    AppRoutes.enroll,
                  );
                  if (ok == true && context.mounted) {
                    context.read<UsersCubit>().load();
                  }
                },
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Enroll'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    () => Navigator.pushNamed(context, AppRoutes.recognize),
                icon: const Icon(Icons.verified_user),
                label: const Text('Recognize'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

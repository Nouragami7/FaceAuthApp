// lib/feature/presentation/widgets/user_card.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';

class UserCard extends StatelessWidget {
  final String name;
  final int id;
  final Uint8List? avatarBytes;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const UserCard({
    super.key,
    required this.name,
    required this.id,
    this.avatarBytes,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundImage: avatarBytes != null ? MemoryImage(avatarBytes!) : null,
          child: avatarBytes == null ? const Icon(Icons.person) : null,
        ),
        title: Text(
          name.isEmpty ? 'Unnamed User' : name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('ID: $id'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

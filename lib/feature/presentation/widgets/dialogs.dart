// lib/feature/presentation/widgets/dialogs.dart
import 'package:flutter/material.dart';

Future<bool?> showConfirmDeleteDialog(BuildContext context, {required String name}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete User'),
      content: Text('Are you sure you want to delete "$name"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton.tonal(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
      ],
    ),
  );
}

Future<String?> showEditNameDialog(BuildContext context, {required String currentName}) {
  final controller = TextEditingController(text: currentName);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Edit Name'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(labelText: 'Name'),
        textInputAction: TextInputAction.done,
        autofocus: true,
        onSubmitted: (_) => Navigator.pop(ctx, controller.text),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Save')),
      ],
    ),
  );
}

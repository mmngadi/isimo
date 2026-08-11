import 'package:flutter/material.dart';
import 'package:flutter_isimo/flutter_isimo.dart';
import 'package:todo_app/src/features/todo/state/todo_state.dart';

/// A dialog for creating a new todo. Selects the `addTodo` action (a stable
/// ref — selecting it never rebuilds the dialog).
Future<void> showAddTodoDialog(BuildContext context) async {
  final title = await showDialog<String>(
    context: context,
    builder: (_) => const _AddTodoDialog(),
  );
  if (title == null || title.trim().isEmpty) return;
  if (!context.mounted) return;
  // Grab the action via read (one-shot dispatch from a lifecycle hook-ish
  // path) — using useStore here would be fine too, but read avoids
  // subscribing the dialog to the store.
  StoreProvider.read<TodoState>(context).value.addTodo(title);
}

class _AddTodoDialog extends StatefulWidget {
  const _AddTodoDialog();

  @override
  State<_AddTodoDialog> createState() => _AddTodoDialogState();
}

class _AddTodoDialogState extends State<_AddTodoDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New todo'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'What needs to be done?'),
        onSubmitted: (_) => Navigator.of(context).pop(_controller.text),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
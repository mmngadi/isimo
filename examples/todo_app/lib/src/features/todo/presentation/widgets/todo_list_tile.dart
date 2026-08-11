import 'package:flutter/material.dart';
import 'package:flutter_isimo/flutter_isimo.dart';
import 'package:todo_app/src/features/todo/domain/model/todo.dart';
import 'package:todo_app/src/features/todo/state/todo_state.dart';

/// A single todo row. Selects its own [Todo] by id and the toggle/remove
/// actions (stable refs) — so toggling one item rebuilds **only this tile**,
/// not the whole list.
class TodoListTile extends StatelessWidget {
  const TodoListTile({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    // Select this todo by id. Returns null if the item was removed between
    // emissions and the rebuild of this tile.
    final todo = context.useStore<TodoState, Todo?>(
      (s) => _selectTodo(s, id),
    );
    if (todo == null) return const SizedBox.shrink();

    // Actions are stable refs — selecting them never rebuilds.
    final toggle = context.useStore<TodoState, void Function(String)>(
      (s) => s.toggle,
    );
    final remove = context.useStore<TodoState, void Function(String)>(
      (s) => s.remove,
    );
    final editTitle = context.useStore<TodoState, void Function(String, String)>(
      (s) => s.editTitle,
    );

    return Dismissible(
      key: ValueKey(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Theme.of(context).colorScheme.errorContainer,
        child: Icon(Icons.delete_outline,
            color: Theme.of(context).colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => remove(todo.id),
      child: ListTile(
        leading: Checkbox(
          value: todo.done,
          onChanged: (_) => toggle(todo.id),
        ),
        title: Text(
          todo.title,
          style: todo.done
              ? TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  decoration: TextDecoration.lineThrough,
                )
              : null,
        ),
        onTap: () async {
          final edited = await showDialog<String>(
            context: context,
            builder: (_) => _EditTodoDialog(initial: todo.title),
          );
          if (edited != null && edited.trim().isNotEmpty) {
            editTitle(todo.id, edited);
          }
        },
      ),
    );
  }
}

/// Selects the [Todo] with [id] from [state], or null if absent.
Todo? _selectTodo(TodoState state, String id) {
  for (final t in state.todos) {
    if (t.id == id) return t;
  }
  return null;
}

class _EditTodoDialog extends StatefulWidget {
  const _EditTodoDialog({required this.initial});
  final String initial;

  @override
  State<_EditTodoDialog> createState() => _EditTodoDialogState();
}

class _EditTodoDialogState extends State<_EditTodoDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit todo'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Title'),
        onSubmitted: (_) => Navigator.of(context).pop(_controller.text),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
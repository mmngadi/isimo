import 'package:flutter/material.dart';
import 'package:flutter_isimo/flutter_isimo.dart';
import 'package:todo_app/src/features/todo/domain/model/todo.dart';
import 'package:todo_app/src/features/todo/domain/model/todo_filter.dart';
import 'package:todo_app/src/features/todo/presentation/widgets/add_todo_dialog.dart';
import 'package:todo_app/src/features/todo/presentation/widgets/todo_list_tile.dart';
import 'package:todo_app/src/features/todo/state/todo_state.dart';

/// The todo screen. Demonstrates isimo's surgical rebuilds:
/// - The header selects a record `({int total, int active})` — rebuilds only
///   when either count changes.
/// - The filter chips row selects the `filter` — rebuilds only on filter
///   change.
/// - The list selects the filtered todos — rebuilds only when the filtered
///   set changes.
/// - The FAB selects the `addTodo` action (stable ref) — never rebuilds.
class TodoScreen extends StatelessWidget {
  const TodoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Header counts via a Dart 3 record — free shallow equality.
    final counts =
        context.useStore<TodoState, ({int total, int active})>(
      (s) => (total: s.todos.length, active: s.todos.where((t) => !t.done).length),
    );

    // The active filter — used by the chips and the empty-state message.
    final filter = context.useStore<TodoState, TodoFilter>((s) => s.filter);

    // The filtered list — the only slice that depends on both todos+filter.
    final visible = context.useStore<TodoState, List<Todo>>((s) {
      return switch (s.filter) {
        TodoFilter.all => s.todos,
        TodoFilter.active => s.todos.where((t) => !t.done).toList(),
        TodoFilter.completed => s.todos.where((t) => t.done).toList(),
      };
    });

    // Actions used directly here are stable refs (FAB shows dialog, then
    // dispatches via read).
    final setFilter =
        context.useStore<TodoState, void Function(TodoFilter)>((s) => s.setFilter);
    final clearCompleted =
        context.useStore<TodoState, void Function()>((s) => s.clearCompleted);

    return Scaffold(
      appBar: AppBar(
        title: Text('Todos · ${counts.active}/${counts.total} active'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear completed',
            onPressed: clearCompleted,
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterChips(filter: filter, onSelected: setFilter),
          const Divider(height: 1),
          Expanded(
            child: visible.isEmpty
                ? _EmptyState(filter: filter)
                : ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (_, i) => TodoListTile(id: visible[i].id),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add'),
        onPressed: () => showAddTodoDialog(context),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.filter, required this.onSelected});
  final TodoFilter filter;
  final void Function(TodoFilter) onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        children: TodoFilter.values.map((f) {
          return ChoiceChip(
            label: Text(f.label),
            selected: f == filter,
            onSelected: (_) => onSelected(f),
          );
        }).toList(),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});
  final TodoFilter filter;

  @override
  Widget build(BuildContext context) {
    final message = switch (filter) {
      TodoFilter.all => 'No todos yet. Tap + to add one.',
      TodoFilter.active => 'No active todos. Nice work!',
      TodoFilter.completed => 'No completed todos.',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      ),
    );
  }
}
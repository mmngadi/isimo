import 'package:isimo/isimo.dart';
import 'package:todo_app/src/features/todo/domain/model/todo.dart';
import 'package:todo_app/src/features/todo/domain/model/todo_filter.dart';
import 'package:todo_app/src/features/todo/state/todo_state.dart';

/// Builds a fresh in-memory todo store for tests (no persistence). Mirrors
/// the action wiring in `todo_store.dart` so tests exercise the real state
/// machine.
Store<TodoState> createInMemoryTodoStore({
  List<Todo> initialTodos = const [],
  TodoFilter initialFilter = TodoFilter.all,
}) {
  late final void Function(String) addTodo;
  late final void Function(String) toggle;
  late final void Function(String) remove;
  late final void Function(String, String) editTitle;
  late final void Function() clearCompleted;
  late final void Function(TodoFilter) setFilter;

  return createStore<TodoState>((set, get) {
    addTodo = (title) {
      final trimmed = title.trim();
      if (trimmed.isEmpty) return;
      set((s) => s.copyWith(
            todos: [
              ...s.todos,
              Todo(
                id: 'test-${s.todos.length}-${DateTime.now().microsecondsSinceEpoch}',
                title: trimmed,
                done: false,
                createdAt: DateTime.now(),
              ),
            ],
          ));
    };
    toggle = (id) => set((s) => s.copyWith(
          todos: s.todos
              .map((t) => t.id == id ? t.copyWith(done: !t.done) : t)
              .toList(),
        ));
    remove = (id) => set((s) => s.copyWith(
          todos: s.todos.where((t) => t.id != id).toList(),
        ));
    editTitle = (id, title) {
      final trimmed = title.trim();
      if (trimmed.isEmpty) return;
      set((s) => s.copyWith(
            todos: s.todos
                .map((t) => t.id == id ? t.copyWith(title: trimmed) : t)
                .toList(),
          ));
    };
    clearCompleted = () => set((s) => s.copyWith(
          todos: s.todos.where((t) => !t.done).toList(),
        ));
    setFilter = (filter) => set((s) => s.copyWith(filter: filter));

    return TodoState(
      todos: initialTodos,
      filter: initialFilter,
      addTodo: addTodo,
      toggle: toggle,
      remove: remove,
      editTitle: editTitle,
      clearCompleted: clearCompleted,
      setFilter: setFilter,
    );
  });
}
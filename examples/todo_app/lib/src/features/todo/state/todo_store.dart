import 'package:flutter/foundation.dart';
import 'package:isimo/isimo.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_app/src/features/todo/data/storage/shared_prefs_storage.dart';
import 'package:todo_app/src/features/todo/domain/mapper/todo_mapper.dart';
import 'package:todo_app/src/features/todo/domain/model/todo.dart';
import 'package:todo_app/src/features/todo/domain/model/todo_filter.dart';
import 'package:todo_app/src/features/todo/state/todo_state.dart';

/// Creates the todo [Store], hydrated from `SharedPreferences` and persisted
/// on every emission.
///
/// Actions are wired **once** (closing over the store's `set`/`get`) and
/// shared between the initial state and the `fromJson` rehydration — so when
/// `persist` calls `store.set((_) => fromJson(json))` on hydrate, only the
/// data (`todos`, `filter`) is replaced and the live action closures carry
/// over.
Future<Store<TodoState>> createTodoStore() async {
  final prefs = SharedPreferencesAsync();
  final storage = SharedPrefsStorage(prefs);

  // Wire the action closures once. They close over `set`/`get`, which are
  // valid once the initializer returns (isimo throws if called during init).
  // We capture them in locals so both the initial state and the fromJson
  // rehydration reference the *same* closures (stable identity).
  late final void Function(String) addTodo;
  late final void Function(String) toggle;
  late final void Function(String) remove;
  late final void Function(String, String) editTitle;
  late final void Function() clearCompleted;
  late final void Function(TodoFilter) setFilter;

  return persist<TodoState>(
    name: 'todos',
    storageEngine: storage,
    initializer: (set, get) {
      // Wire actions to `set` (replace-by-function, immutable updates).
      addTodo = (title) {
        final trimmed = title.trim();
        if (trimmed.isEmpty) return;
        set((s) => s.copyWith(
              todos: [
                ...s.todos,
                Todo(
                  id: _newId(),
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
        todos: const [],
        filter: TodoFilter.all,
        addTodo: addTodo,
        toggle: toggle,
        remove: remove,
        editTitle: editTitle,
        clearCompleted: clearCompleted,
        setFilter: setFilter,
      );
    },
    toJson: (s) => todoStateToJson(s.todos, s.filter),
    fromJson: (json) {
      final rawTodos = json['todos'] as List<dynamic>? ?? const [];
      final todos = rawTodos
          .map((e) => todoFromJson(e as Map<String, dynamic>))
          .toList();
      final filter = TodoFilter.values.firstWhere(
        (f) => f.name == json['filter'],
        orElse: () => TodoFilter.all,
      );
      // Re-wire the same action closures captured above. Only data is
      // rehydrated; actions keep their stable identity.
      return TodoState(
        todos: todos,
        filter: filter,
        addTodo: addTodo,
        toggle: toggle,
        remove: remove,
        editTitle: editTitle,
        clearCompleted: clearCompleted,
        setFilter: setFilter,
      );
    },
    onError: (error, stackTrace) {
      debugPrint('todo persist error: $error\n$stackTrace');
    },
  );
}

int _idCounter = 0;

/// Generates a locally-unique id (timestamp + monotonic counter). Sufficient
/// for a single-user, single-device todo app.
String _newId() {
  _idCounter += 1;
  return '${DateTime.now().microsecondsSinceEpoch}-$_idCounter';
}
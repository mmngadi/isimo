import 'package:isimo/isimo.dart';
import 'package:todo_app/src/features/todo/domain/model/todo.dart';
import 'package:todo_app/src/features/todo/domain/model/todo_filter.dart';

/// Aggregate state of the todo feature: the full list of [todos], the active
/// [filter], and the action closures (final, stable refs).
///
/// Equality comes from [StoreState] — [props] lists **data fields only**
/// (`todos`, `filter`); action closures are stable refs and are omitted so
/// two states with equal data compare equal (what rebuild dedup relies on).
class TodoState with StoreState {
  final List<Todo> todos;
  final TodoFilter filter;

  // Actions — final closure fields (stable references; selecting them via
  // useStore never rebuilds).
  final void Function(String title) addTodo;
  final void Function(String id) toggle;
  final void Function(String id) remove;
  final void Function(String id, String title) editTitle;
  final void Function() clearCompleted;
  final void Function(TodoFilter filter) setFilter;

  const TodoState({
    this.todos = const [],
    this.filter = TodoFilter.all,
    required this.addTodo,
    required this.toggle,
    required this.remove,
    required this.editTitle,
    required this.clearCompleted,
    required this.setFilter,
  });

  @override
  TodoState copyWith({List<Todo>? todos, TodoFilter? filter}) => TodoState(
        todos: todos ?? this.todos,
        filter: filter ?? this.filter,
        addTodo: addTodo,
        toggle: toggle,
        remove: remove,
        editTitle: editTitle,
        clearCompleted: clearCompleted,
        setFilter: setFilter,
      );

  // Data fields only — actions are stable refs, omitted from equality.
  @override
  List<Object?> get props => [todos, filter];
}
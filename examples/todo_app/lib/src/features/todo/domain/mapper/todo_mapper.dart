import 'package:todo_app/src/features/todo/domain/model/todo.dart';
import 'package:todo_app/src/features/todo/domain/model/todo_filter.dart';

/// Serializes a [Todo] to a JSON map.
Map<String, dynamic> todoToJson(Todo todo) => {
      'id': todo.id,
      'title': todo.title,
      'done': todo.done,
      'createdAt': todo.createdAt.toIso8601String(),
    };

/// Deserializes a [Todo] from a JSON map.
Todo todoFromJson(Map<String, dynamic> json) => Todo(
      id: json['id'] as String,
      title: json['title'] as String,
      done: json['done'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

/// Serializes the aggregate [TodoState] for persistence. Lives in the domain
/// layer (it only touches domain models) so the data layer can import it.
Map<String, dynamic> todoStateToJson(List<Todo> todos, TodoFilter filter) => {
      'todos': todos.map(todoToJson).toList(),
      'filter': filter.name,
    };
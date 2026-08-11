/// A single todo item — an immutable value object.
///
/// This is *not* a [StoreState]; it is an element of the aggregate
/// [TodoState]. Equality is structural so two [Todo]s with the same fields
/// compare equal (used by selector dedup).
class Todo {
  final String id;
  final String title;
  final bool done;
  final DateTime createdAt;

  const Todo({
    required this.id,
    required this.title,
    required this.done,
    required this.createdAt,
  });

  Todo copyWith({String? title, bool? done}) => Todo(
        id: id,
        title: title ?? this.title,
        done: done ?? this.done,
        createdAt: createdAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Todo &&
          other.id == id &&
          other.title == title &&
          other.done == done &&
          other.createdAt == createdAt);

  @override
  int get hashCode => Object.hash(id, title, done, createdAt);
}
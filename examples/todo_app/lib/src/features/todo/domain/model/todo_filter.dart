/// Filter applied to the todo list.
enum TodoFilter {
  all,
  active,
  completed,
}

/// Extension of [TodoFilter] with the user-facing label.
extension TodoFilterX on TodoFilter {
  String get label => switch (this) {
        TodoFilter.all => 'All',
        TodoFilter.active => 'Active',
        TodoFilter.completed => 'Completed',
      };
}
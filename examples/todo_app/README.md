# todo_app

A fully operational todo app built to **stress-test the `isimo` + `flutter_isimo`**
state management packages. It exercises the core packages end-to-end: immutable
`StoreState` with colocated actions, `createStore`, `persist` with a custom
`StorageEngine` adapter, `StoreProvider` scoping, and the `context.useStore`
selector hook with **surgical rebuilds**.

## Planning

### Goals

- Use `isimo` strictly for all state management (no `ChangeNotifier`,
  `ValueNotifier`, `setState`, or other state holders in the presentation
  layer). This is the point of the app — to validate isimo as a package.
- Cover isimo's full public API surface in a real feature:
  - `StoreState` mixin (`props`-based `==`/`hashCode`, `copyWith`).
  - `createStore<T>` with an initializer that wires action closures.
  - `Store.set` replace-by-function updates via `copyWith`.
  - Equality dedup (toggling to the same state → no spurious emission).
  - `persist<T>` with a custom `StorageEngine` (`SharedPreferencesAsync`).
  - `flutter_isimo`: `StoreProvider<T>`, `StoreProvider.of`, `StoreProvider.read`,
    and `context.useStore<T, R>(selector, {equals})`.
  - Surgical rebuilds: a widget calling `useStore` multiple times registers
    multiple independent selectors; only the changed slice rebuilds.
  - Dart 3 record selectors for multi-field shallow comparison.
  - Stable action refs: selecting an action never rebuilds.

### Architecture

Follows the monorepo's feature-scoped layout (`lib/src/features/<feature>/`).
isimo stores replace the `ChangeNotifier`-ViewModel layer; selectors read
directly from the store, so there is no `*_ui_state.dart` / `*_view_model.dart`.

```
todo_app/
├── pubspec.yaml                         # path deps on isimo + flutter_isimo, shared_preferences
├── README.md                            # this file
├── lib/
│   ├── main.dart                        # ~5 lines: hydrate store, runApp
│   ├── app.dart                         # MaterialApp root; wires StoreProvider<TodoState>
│   └── src/features/todo/
│       ├── domain/
│       │   ├── model/
│       │   │   ├── todo.dart            # immutable value object (id, title, done, createdAt)
│       │   │   └── todo_filter.dart     # enum {all, active, completed} + label
│       │   └── mapper/
│       │       └── todo_mapper.dart     # todo ↔ JSON, todoStateToJson (used by persist)
│       ├── data/
│       │   └── storage/
│       │       └── shared_prefs_storage.dart  # StorageEngine adapter (SharedPreferencesAsync)
│       ├── state/
│       │   ├── todo_state.dart          # TodoState with StoreState (todos, filter, actions)
│       │   └── todo_store.dart         # createTodoStore() → persist<TodoState> wiring
│       └── presentation/
│           ├── todo_screen.dart         # Scaffold, filter chips, list, empty-state, FAB
│           └── widgets/
│               ├── todo_list_tile.dart  # per-item: selects its own Todo by id (surgical)
│               └── add_todo_dialog.dart # new-todo dialog
└── test/
    ├── helpers/
    │   └── todo_store_test_helper.dart  # in-memory store factory (no persistence) for tests
    └── todo_app_test.dart               # widget tests
```

### State model

`TodoState` is the aggregate `StoreState`:

```dart
class TodoState with StoreState {
  final List<Todo> todos;          // data
  final TodoFilter filter;         // data
  final void Function(String title) addTodo;            // action (stable ref)
  final void Function(String id) toggle;                // action
  final void Function(String id) remove;                // action
  final void Function(String id, String title) editTitle; // action
  final void Function() clearCompleted;                 // action
  final void Function(TodoFilter filter) setFilter;     // action

  @override
  TodoState copyWith({List<Todo>? todos, TodoFilter? filter}) => TodoState(
        todos: todos ?? this.todos,
        filter: filter ?? this.filter,
        addTodo: addTodo, toggle: toggle, remove: remove,
        editTitle: editTitle, clearCompleted: clearCompleted, setFilter: setFilter,
      );

  @override
  List<Object?> get props => [todos, filter]; // data only — actions omitted
}
```

`Todo` is a plain immutable value object (no `StoreState`) — it is an element
of the aggregate, with structural `==`/`hashCode` so two `Todo`s with the same
fields compare equal (used by selector dedup).

### Actions

Actions are `final` closure fields on `TodoState`, wired **once** in the store
initializer (closing over `set`/`get`) and **shared** between the initial state
and `persist`'s `fromJson` rehydration. When `persist` hydrates, it calls
`store.set((_) => fromJson(json))`, which replaces only the **data** (`todos`,
`filter`); the live action closures carry over unchanged (stable identity).

All mutations use replace-by-function + `copyWith`:

```dart
addTodo = (title) => set((s) => s.copyWith(todos: [...s.todos, Todo(...)]));
toggle = (id) => set((s) => s.copyWith(todos: s.todos.map(
  (t) => t.id == id ? t.copyWith(done: !t.done) : t).toList()));
```

### Persistence

`SharedPrefsStorage implements StorageEngine` wraps `SharedPreferencesAsync`.
`createTodoStore()` calls `persist<TodoState>`:

- hydrates from `prefs.getString('todos')` on startup;
- persists on every emission via `store.listen` (isimo's contract — never
  reassigns `store.set`);
- `toJson` picks `todos` + `filter`; `fromJson` rebuilds a `TodoState` with the
  rehydrated data and the same action closures;
- `onError` logs storage failures (never silently swallowed).

`main.dart` awaits the store before `runApp`, so the UI mounts with hydrated
state.

### Surgical rebuilds (the isimo stress-test)

| Widget                | Selectors                                                | Rebuilds when                                |
|-----------------------|----------------------------------------------------------|----------------------------------------------|
| `TodoScreen` header   | `({int total, int active})` (Dart 3 record)             | total or active count changes                |
| `TodoScreen` chips    | `TodoFilter filter`                                      | filter changes                               |
| `TodoScreen` list     | `List<Todo>` (filtered by current filter)                | the filtered set changes                     |
| `TodoScreen` actions  | `setFilter`, `clearCompleted` (stable refs)             | never (actions are stable)                   |
| `TodoListTile`        | `Todo?` by id, `toggle`/`remove`/`editTitle` (refs)     | only this todo changes                       |
| FAB / dialogs         | actions via `StoreProvider.read` (one-shot dispatch)    | never (read does not subscribe)             |

A single widget calls `useStore` multiple times; each call registers an
independent selector. Toggling one tile rebuilds **only that tile** — the
header counts, filter chips, and sibling tiles do not rebuild unless their
own slice changed.

### Workspace setup

`todo_app` is a member of the root pub workspace (`pubspec.yaml` `workspace:`
lists `isimo`, `flutter_isimo`, `todo_app`) and uses path dependencies on the
sibling packages:

```yaml
dependencies:
  flutter:
    sdk: flutter
  isimo:
    path: ../isimo
  flutter_isimo:
    path: ../flutter_isimo
  shared_preferences: ^2.3.2
```

`dart pub get` runs from the **repo root** (workspace mode).

## Features

- Add, toggle, edit (tap a tile), and delete (swipe) todos.
- Filter by All / Active / Completed (choice chips).
- Clear completed (AppBar action).
- Active/total count in the AppBar.
- Local persistence via `SharedPreferences` (survives restarts).
- Per-item surgical rebuilds.

## Getting started

From the repo root:

```bash
dart pub get          # workspace mode — resolves all three packages
cd todo_app
flutter run           # run on your device/emulator of choice
```

## Testing

```bash
cd todo_app
flutter test          # 9 widget tests
```

Tests cover: empty initial state, add via dialog, toggle + filter movement,
clear completed, blank-title no-op, swipe-to-delete, edit title,
`StoreProvider.read` non-subscribing, and the surgical-rebuild claim (a sibling
tile's checkbox value is unchanged when another toggles). Tests use an
in-memory store factory (no persistence) for determinism.

From the repo root, `dart analyze` reports **No issues found** across all
three packages.

## License

MIT — see the repo root `LICENSE`.
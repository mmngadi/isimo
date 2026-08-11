# isimo

A lightweight, zero-boilerplate, atomic state management engine for Dart —
heavily inspired by Zustand. The `isimo` package is the **pure Dart core**:
zero Flutter dependencies, usable in Flutter apps, server/CLI tools, or pure
Dart unit tests.

Companion Flutter bindings live in the
[`flutter_isimo`](https://pub.dev/packages/flutter_isimo) package.

## Features

- **Zero code generation.** No `build_runner`, no `.g.dart`. Hand-written
  `copyWith` + `props` — the one-time cost of staying codegen-free.
- **100% pure Dart core.** Use `isimo` anywhere the Dart SDK runs.
- **Immutable state contract.** The `StoreState` mixin provides value `==` /
  `hashCode` from a single `props` getter (data fields only) and requires a
  `copyWith` override (a compile-time guard against omission).
- **Equality dedup.** `Store.set` skips emission when the new state equals
  the old (`==`), so equal-data states don't trigger rebuilds or persistence.
- **Replace-by-function `set`.** `set((s) => s.copyWith(count: s.count + 1))`
  — never in-place mutation.
- **Type-safe actions.** Actions are `final` closure fields on the state
  class (stable references).
- **Synchronous & async safety.** `set` for updates, `get` for fresh reads
  across `await` boundaries.
- **Pluggable persistence.** The adapter-based `persist` middleware works
  with `SharedPreferences`, `FlutterSecureStorage`, `Hive`, or in-memory test
  mocks via the `StorageEngine` interface.

## Getting started

Add `isimo` to your `pubspec.yaml`:

```yaml
dependencies:
  isimo: ^1.0.0
```

For Flutter apps, also add the bindings:

```yaml
dependencies:
  isimo: ^1.0.0
  flutter_isimo: ^1.0.0
```

## Usage

### Define state & actions

```dart
import 'package:isimo/isimo.dart';

class CounterState with StoreState {
  final int count;
  final void Function() increment;

  const CounterState({this.count = 0, required this.increment});

  @override
  CounterState copyWith({int? count}) => CounterState(
        count: count ?? this.count,
        increment: increment,
      );

  // Data fields only — actions are stable refs, omitted from equality.
  @override
  List<Object?> get props => [count];
}
```

### Create the store

```dart
final counterStore = createStore<CounterState>((set, get) => CounterState(
      count: 0,
      increment: () => set((s) => s.copyWith(count: s.count + 1)),
    ));
```

### Subscribe in pure Dart

```dart
final sub = counterStore.listen((s) => print('count -> ${s.count}'));
counterStore.value.increment(); // prints: count -> 1
sub.cancel();
counterStore.dispose();
```

### Persistence

```dart
class MemoryStorage implements StorageEngine {
  final Map<String, String> _map = {};
  @override
  Future<String?> getItem(String key) async => _map[key];
  @override
  Future<void> setItem(String key, String value) async => _map[key] = value;
  @override
  Future<void> removeItem(String key) async => _map.remove(key);
}

Future<Store<CounterState>> makeStore() => persist<CounterState>(
      name: 'counter',
      storageEngine: MemoryStorage(),
      initializer: (set, get) => CounterState(
        count: 0,
        increment: () => set((s) => s.copyWith(count: s.count + 1)),
      ),
      toJson: (s) => {'count': s.count},
      fromJson: (json) => CounterState(
        count: json['count'] as int? ?? 0,
        increment: () {}, // wire the real action in your app
      ),
      onError: (error, stackTrace) => print('persist error: $error'),
    );
```

A runnable example lives in [`example/isimo_example.dart`](example/isimo_example.dart).

## API

| Primitive         | Type      | Description                                              |
|-------------------|-----------|----------------------------------------------------------|
| `createStore<T>`  | `Function`| Instantiates a `Store<T>` from an initializer.          |
| `Store<T>`        | `Class`   | `value`, `set(T Function(T))`, `listen`, `dispose`.     |
| `StoreState`      | `Mixin`    | Value `==`/`hashCode` from `props`; requires `copyWith`.|
| `persist<T>`      | `Function`| Hydrate + persist-on-emission middleware.               |
| `StorageEngine`   | `Interface`| Abstract adapter for custom storage drivers.           |

## Additional information

- License: MIT. See the root repository `LICENSE`.
- Issues and contributions: see the monorepo on GitHub.
- Flutter bindings: `flutter_isimo`.
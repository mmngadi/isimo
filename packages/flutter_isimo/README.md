# flutter_isimo

Flutter bindings for the [`isimo`](https://pub.dev/packages/isimo) state
management engine. Scopes pure Dart `Store<T>` instances into the widget tree
via `StoreProvider<T>` and provides the `context.useStore` selector hook for
**surgical, equality-gated rebuilds** — widgets rebuild only when their
selected slice changes, not on every store emission.

## Features

- **`StoreProvider<T>`** scopes a `Store<T>` down the tree. Subclass to build
  domain-specific providers (`CounterProvider`, `AuthProvider`, …).
- **`context.useStore<T, R>(selector, {equals})`** — the single context hook.
  Rebuilds the calling widget only when the selected slice `R` changes
  (default `==`, or a custom `equals`).
- **Surgical rebuilds** via a custom `InheritedWidget` + `InheritedElement`
  that gates each dependent by selector equality (NOT `InheritedNotifier`,
  which broadcasts to all dependents).
- **Dart 3 records for multi-select.** `useStore<T, (int, String)>((s) => (s.a, s.b))`
  gives free shallow comparison via structural `==`.
- **Stable actions.** Selecting an action (a `final` closure field) never
  rebuilds — actions have stable identity across state updates.
- **`StoreProvider.of<T>(ctx)`** subscribes (rebuilds on any change);
  **`StoreProvider.read<T>(ctx)`** is non-subscribing (for `initState` or
  grabbing the `Store<T>` handle).

## Getting started

```yaml
dependencies:
  flutter:
    sdk: flutter
  isimo: ^1.0.0
  flutter_isimo: ^1.0.0
```

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:isimo/isimo.dart';
import 'package:flutter_isimo/flutter_isimo.dart';

class CounterState with StoreState {
  final int count;
  final void Function() increment;
  const CounterState({this.count = 0, required this.increment});

  @override
  CounterState copyWith({int? count}) =>
      CounterState(count: count ?? this.count, increment: increment);

  @override
  List<Object?> get props => [count];
}

final counterStore = createStore<CounterState>((set, get) => CounterState(
      count: 0,
      increment: () => set((s) => s.copyWith(count: s.count + 1)),
    ));

void main() => runApp(
      StoreProvider<CounterState>(
        store: counterStore,
        child: const MaterialApp(home: CounterPage()),
      ),
    );

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuilds only when `count` changes.
    final count = context.useStore<CounterState, int>((s) => s.count);
    // Stable ref — never rebuilds.
    final increment =
        context.useStore<CounterState, void Function()>((s) => s.increment);

    return Scaffold(
      body: Center(child: Text('$count')),
      floatingActionButton: FloatingActionButton(
        onPressed: increment,
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

A runnable example lives in
[`example/flutter_isimo_example.dart`](example/flutter_isimo_example.dart).

## API

| Primitive                 | Type              | Description                                       |
|---------------------------|-------------------|---------------------------------------------------|
| `StoreProvider<T>`        | `StatefulWidget`  | Scopes a `Store<T>` down the tree.                |
| `StoreProvider.of<T>`     | `Static Method`   | Subscribing accessor (rebuilds on any change).    |
| `StoreProvider.read<T>`   | `Static Method`   | Non-subscribing accessor (lifecycle hooks).       |
| `context.useStore<T, R>`  | `Extension Method`| Select a slice; rebuild only when it changes.     |

## Additional information

- License: MIT. See the root repository `LICENSE`.
- The pure Dart core: [`isimo`](https://pub.dev/packages/isimo).
- Issues and contributions: see the monorepo on GitHub.
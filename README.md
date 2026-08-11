# Isimo

A lightweight, zero-boilerplate, atomic state management engine for Dart and Flutter — heavily inspired by Zustand.

Isimo uses a decoupled **Core-and-Binding** architecture: a pure Dart core (`isimo`) with zero Flutter dependencies, and a Flutter bindings companion (`flutter_isimo`) for surgical UI rebuilds.

```text
isimo_monorepo/
├── packages/
│   ├── isimo/            # Pure Dart core (zero Flutter SDK dependency)
│   └── flutter_isimo/    # Flutter widget bindings & BuildContext extensions
├── examples/
│   └── todo_app/         # Full Flutter app stress-testing both packages
└── LICENSE
```

---

## Key Features

- **Zero Code Generation** — No `build_runner`, `.g.dart`, or macros. Hand-written `copyWith` + `StoreState` mixin; use `freezed` in your own app if you prefer generated code.
- **100% Pure Dart Core** — Use `isimo` in Flutter apps, Dart servers, CLI tools, or pure Dart tests.
- **Surgical UI Rebuilds** — `context.useStore<T, R>(selector)` rebuilds only when the selected slice changes (`==`-gated).
- **Type-Safe Colocated Actions** — Actions are `final` closures on the state class; selecting one never rebuilds (stable reference).
- **Pluggable Persistence** — `persist` middleware with any `StorageEngine` adapter (`SharedPreferences`, `FlutterSecureStorage`, `Hive`, in-memory mocks).
- **Dart 3 Records** — Free structural `==` for multi-field selection; no `shallowEquals` helper needed.

---

## Installation

Add both packages to your Flutter app's `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  isimo: ^1.0.0
  flutter_isimo: ^1.0.0
```

For a pure Dart CLI or backend service, import `isimo` alone.

---

## Quick Start

### 1. Define State & Actions

```dart
import 'package:isimo/isimo.dart';

class CounterState with StoreState {
  final int count;
  final String userRole;

  final void Function() increment;
  final void Function(int amount) addBy;

  const CounterState({
    this.count = 0,
    this.userRole = 'Guest',
    required this.increment,
    required this.addBy,
  });

  @override
  CounterState copyWith({int? count, String? userRole}) => CounterState(
        count: count ?? this.count,
        userRole: userRole ?? this.userRole,
        increment: increment,
        addBy: addBy,
      );

  @override
  List<Object?> get props => [count, userRole];
}
```

### 2. Create the Store

```dart
import 'package:isimo/isimo.dart';

final counterStore = createStore<CounterState>((set, get) {
  return CounterState(
    count: 0,
    userRole: 'Guest',
    increment: () => set((s) => s.copyWith(count: s.count + 1)),
    addBy: (amount) => set((s) => s.copyWith(count: s.count + amount)),
  );
});
```

### 3. Scope & Consume in Flutter

```dart
import 'package:flutter/material.dart';
import 'package:flutter_isimo/flutter_isimo.dart';

// Scope with StoreProvider<T>
runApp(
  StoreProvider(
    store: counterStore,
    child: const MyApp(),
  ),
);

// Consume slices — rebuilds only when the slice changes
class CounterWidget extends StatelessWidget {
  const CounterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final count = context.useStore<CounterState, int>((s) => s.count);
    final increment = context.useStore<CounterState, void Function()>(
      (s) => s.increment,
    );

    return Column(
      children: [
        Text('Count: $count'),
        ElevatedButton(onPressed: increment, child: const Text('Increment')),
      ],
    );
  }
}
```

---

## API Overview

| Package | Primitive | Description |
|---|---|---|
| `isimo` | `createStore<T>` | Instantiates a reactive store holding your state and actions. |
| `isimo` | `Store<T>` | `value`, `set(T Function(T))`, `listen`, `dispose`. |
| `isimo` | `StoreState` | Mixin: value `==`/`hashCode` from `props` + requires `copyWith`. |
| `isimo` | `persist<T>` | Hydration + disk persistence middleware. |
| `isimo` | `StorageEngine` | Abstract adapter for custom storage drivers. |
| `flutter_isimo` | `StoreProvider<T>` | Scopes a `Store<T>` down the widget tree. |
| `flutter_isimo` | `StoreProvider.of<T>` | Subscribing accessor (rebuilds on any change). |
| `flutter_isimo` | `StoreProvider.read<T>` | Non-subscribing accessor (for `initState` / event handlers). |
| `flutter_isimo` | `context.useStore<T, R>` | Selects a slice; rebuilds only when it changes. |

---

## Persistence

```dart
import 'package:isimo/isimo.dart';

Future<Store<UserSettingsState>> createSettingsStore() async {
  return persist<UserSettingsState>(
    name: 'user_settings',
    storageEngine: SharedPrefsStorage(),
    initializer: (set, get) => UserSettingsState(
      themeMode: 'system',
      setThemeMode: (mode) => set((s) => s.copyWith(themeMode: mode)),
    ),
    toJson: (s) => {'themeMode': s.themeMode},
    fromJson: (json) => UserSettingsState.initial(
      themeMode: json['themeMode'] as String? ?? 'system',
    ),
    onError: (error, stackTrace) {
      // log/handle persistence errors here
    },
  );
}
```

---

## License

MIT — see [LICENSE](LICENSE).
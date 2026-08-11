## 1.0.0

- Initial release of the `isimo` pure Dart state management core.
- `StoreState` mixin: value `==`/`hashCode` from a `props` getter (data fields
  only, collection-aware deep equality); abstract `copyWith` guards omission.
- `Store<T>`: replace-by-function `set(T Function(T))` with equality dedup,
  `value` getter, `listen`, and `dispose`.
- `createStore<T>`: instantiate a typed store from an initializer.
- `StorageEngine` abstract interface for pluggable storage adapters.
- `persist<T>` middleware: hydrate on construction, persist on emission via
  `store.listen` (never reassigns `set`), with `toJson`/`fromJson` and an
  optional `onError`.
- Zero Flutter dependencies (only `dart:async` and `dart:convert`).
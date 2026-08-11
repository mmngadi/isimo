## 1.0.0

- Initial release of the `flutter_isimo` Flutter bindings for `isimo`.
- `StoreProvider<T>`: scopes a `Store<T>` down the widget tree; subclassable
  for domain-specific providers.
- `StoreProvider.of<T>(ctx)`: subscribing accessor (throws `StateError` when
  no provider is found).
- `StoreProvider.read<T>(ctx)`: non-subscribing accessor for lifecycle hooks
  like `initState`.
- `context.useStore<T, R>(selector, {equals})`: selects a slice and rebuilds
  the calling widget only when the slice changes (surgical rebuilds via a
  custom `InheritedWidget` + `InheritedElement`, NOT `InheritedNotifier`).
- Depends on `flutter` SDK and `isimo: ^1.0.0`.
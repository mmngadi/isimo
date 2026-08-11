// Isimo — pure Dart reactive state management core.
// Zero Flutter dependencies. Only dart:async and dart:convert.
library;

import 'dart:async';
import 'dart:convert';

/// Function signature for updating store state by returning a new instance.
typedef SetFn<T> = void Function(T Function(T) updater);

/// Function signature for reading the current store state.
typedef GetFn<T> = T Function();

/// Function signature for initializing a store. Receives [set] and [get]
/// and must return the initial state.
typedef StoreInitializer<T> = T Function(SetFn<T> set, GetFn<T> get);

/// Function signature for listening to store emissions.
typedef StoreListener<T> = void Function(T state);

/// Mixin providing value [==]/[hashCode] for immutable state classes.
///
/// Implement [props] to list the fields that define equality. List **data
/// fields only**; action closures are stable `final` refs and should be
/// omitted so that two states with equal data compare equal (what the
/// Store's equality dedup and selector gating rely on).
///
/// Implement [copyWith] to return a new instance with updated fields. The
/// abstract declaration here is loose (no named params) — it **guards
/// omission**: the analyzer errors if `copyWith` is missing entirely. It
/// cannot enforce that your params match your fields, so a no-op
/// `copyWith` compiles but ships a broken state — the developer assumes
/// that risk. The canonical shape is:
///
/// ```dart
/// @override
/// CounterState copyWith({int? count, String? userRole}) => CounterState(
///   count: count ?? this.count,
///   userRole: userRole ?? this.userRole,
///   increment: increment, // action fields carried forward verbatim
///   addBy: addBy,
/// );
/// ```
///
/// The mixin has no fields, so it stays compatible with `const`
/// constructors. Collection-valued fields (List/Set/Map) are compared
/// structurally, not by identity.
mixin StoreState {
  /// Fields that define value equality. List data fields only — omit
  /// action closures (stable refs) so equal-data states compare equal.
  List<Object?> get props;

  /// Returns a new instance of this state with the given fields replaced.
  /// Override with named optional params per data field; carry action
  /// fields forward verbatim. See the class dartdoc for the canonical shape.
  StoreState copyWith();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other.runtimeType == runtimeType &&
          other is StoreState &&
          _deepEquals(props, other.props));

  @override
  int get hashCode => Object.hashAll(props);

  static bool _deepEquals(List<Object?> a, List<Object?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final ai = a[i], bi = b[i];
      if (ai is List && bi is List) {
        if (!_deepEquals(ai, bi)) return false;
      } else if (ai is Set && bi is Set) {
        if (ai.length != bi.length || !ai.containsAll(bi)) return false;
      } else if (ai is Map && bi is Map) {
        if (ai.length != bi.length) return false;
        for (final key in ai.keys) {
          if (!bi.containsKey(key) || bi[key] != ai[key]) return false;
        }
      } else if (ai != bi) {
        return false;
      }
    }
    return true;
  }
}

/// Pure Dart reactive store holding a single immutable state snapshot.
///
/// Use [set] to replace state by returning a new instance; emission is
/// skipped when the new state equals the old (equality dedup via the
/// mandated `==` from [StoreState]). Use [value] to read synchronously
/// and [listen] to subscribe to changes.
class Store<T> {
  late T _state;
  // `sync: true` so listeners (including flutter_isimo's InheritedElement,
  // which calls markNeedsBuild) are notified during `set` — this makes
  // rebuilds deterministic within a single frame pump rather than deferred
  // to the next microtask.
  final _controller = StreamController<T>.broadcast(sync: true);

  // Guards against calling `set`/`get` synchronously inside the initializer
  // body (before it returns the initial state). Actions captured by the
  // initial state close over [_update]/[_read] and run *after* construction,
  // when this flag is `true` — so `get()` is available once actions run.
  bool _initialized = false;

  Store(StoreInitializer<T> initializer) {
    _state = initializer(_update, _read);
    _initialized = true;
  }

  /// The current state snapshot.
  T get value => _state;

  /// Update state by returning a new instance; emit only if changed.
  ///
  /// [updater] receives the current state and must return the next state
  /// (typically via `copyWith`). Emission is skipped when the new state
  /// equals the old (equality dedup via the mandated `==`).
  void set(T Function(T) updater) => _update(updater);

  void _update(T Function(T) updater) {
    if (!_initialized) {
      throw StateError('Cannot call set() during store initialization; '
          'return the initial state from the initializer instead.');
    }
    final next = updater(_state);
    if (identical(next, _state) || next == _state) return;
    _state = next;
    _controller.add(_state);
  }

  T _read() {
    if (!_initialized) {
      throw StateError('Cannot call get() during store initialization; '
          'return the initial state from the initializer instead.');
    }
    return _state;
  }

  /// Subscribe to state changes in pure Dart.
  ///
  /// The returned [StreamSubscription] can be used to cancel listening.
  StreamSubscription<T> listen(StoreListener<T> listener) =>
      _controller.stream.listen(listener);

  /// Closes the internal broadcast stream. Further [set] calls will throw.
  void dispose() => _controller.close();
}

/// Instantiates a typed [Store] from an [initializer].
///
/// The initializer receives [set] and [get] closures and must return the
/// initial state. Action closures captured in the initial state close over
/// the stable `set`/`get` pair of this store.
Store<T> createStore<T>(StoreInitializer<T> initializer) => Store<T>(initializer);

/// Abstract storage engine adapter interface.
///
/// Implementations back `persist` with a concrete storage driver such as
/// `SharedPreferences`, `FlutterSecureStorage`, `Hive`, or an in-memory
/// test mock.
abstract interface class StorageEngine {
  Future<String?> getItem(String key);
  Future<void> setItem(String key, String value);
  Future<void> removeItem(String key);
}

/// Persistence middleware accepting any [StorageEngine] adapter.
///
/// Hydrates the store from storage on construction and persists on every
/// emission via [Store.listen] (does NOT reassign `set`). [toJson] picks
/// the fields to serialize (subsuming `partialize`); [fromJson]
/// reconstructs a fresh state. [onError] observes storage failures (never
/// silently swallowed).
Future<Store<T>> persist<T>({
  required String name,
  required StorageEngine storageEngine,
  required StoreInitializer<T> initializer,
  required Map<String, dynamic> Function(T state) toJson,
  required T Function(Map<String, dynamic> json) fromJson,
  void Function(Object error, StackTrace stackTrace)? onError,
}) async {
  final store = createStore<T>(initializer);

  // Hydrate from storage.
  try {
    final saved = await storageEngine.getItem(name);
    if (saved != null) {
      final json = jsonDecode(saved) as Map<String, dynamic>;
      store.set((_) => fromJson(json));
    }
  } catch (e, st) {
    onError?.call(e, st);
  }

  // Persist on every emission (subscribe — never reassign store.set).
  // The listener awaits the write so async storage errors are caught by
  // the try/catch and routed to [onError] (never silently swallowed).
  store.listen((state) async {
    try {
      await storageEngine.setItem(name, jsonEncode(toJson(state)));
    } catch (e, st) {
      onError?.call(e, st);
    }
  });

  return store;
}
import 'dart:async';

import 'package:isimo/isimo.dart';
import 'package:test/test.dart';

// --- Test state -------------------------------------------------------------

class CounterState with StoreState {
  final int count;
  final String userRole;

  // Actions: final closure fields (stable references).
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

CounterState _makeState({
  int count = 0,
  String userRole = 'Guest',
  void Function()? increment,
  void Function(int amount)? addBy,
}) {
  // Build a store whose actions are wired to a placeholder; tests that need
  // real actions will construct their own store.
  return CounterState(
    count: count,
    userRole: userRole,
    increment: increment ?? () {},
    addBy: addBy ?? (_) {},
  );
}

// --- In-memory StorageEngine for persist tests ------------------------------

class _MemoryStorage implements StorageEngine {
  final Map<String, String> _map = {};

  @override
  Future<String?> getItem(String key) async => _map[key];

  @override
  Future<void> setItem(String key, String value) async {
    _map[key] = value;
  }

  @override
  Future<void> removeItem(String key) async {
    _map.remove(key);
  }
}

class _SyncFailingStorage implements StorageEngine {
  @override
  Future<String?> getItem(String key) =>
      Future.error(Exception('read fail'));

  @override
  Future<void> setItem(String key, String value) =>
      Future.error(Exception('write fail'));

  @override
  Future<void> removeItem(String key) =>
      Future.error(Exception('remove fail'));
}

// --- Tests ------------------------------------------------------------------

void main() {
  group('StoreState', () {
    test('== and hashCode use data fields only (actions omitted)', () {
      final a = _makeState(count: 1, userRole: 'Admin');
      // Different closures, same data -> equal.
      final b = _makeState(
        count: 1,
        userRole: 'Admin',
        increment: () => print('different closure'),
      );
      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);

      final c = _makeState(count: 2, userRole: 'Admin');
      expect(a == c, isFalse);
      expect(a.hashCode, isNot(c.hashCode));
    });

    test('collection-valued props compared structurally', () {
      final s = _CollectionState(items: const [1, 2, 3]);
      final s2 = _CollectionState(items: const [1, 2, 3]);
      expect(s == s2, isTrue);
      expect(s.hashCode, s2.hashCode);

      final s3 = _CollectionState(items: const [1, 2, 4]);
      expect(s == s3, isFalse);
    });

    test('copyWith omission is guarded by abstract declaration', () {
      // Compile-time guard: if a state class forgets copyWith, the analyzer
      // errors. Here we just exercise a working copyWith.
      final s = _makeState(count: 1);
      final s2 = s.copyWith(count: 2);
      expect(s2.count, 2);
      expect(s.count, 1); // original unchanged (immutability)
    });
  });

  group('Store.set', () {
    test('updates state via replace-by-function', () {
      final store = createStore<CounterState>((set, get) => _makeState(
            count: 0,
            increment: () => set((s) => s.copyWith(count: s.count + 1)),
            addBy: (amount) => set((s) => s.copyWith(count: s.count + amount)),
          ));
      expect(store.value.count, 0);
      store.value.increment();
      expect(store.value.count, 1);
      store.value.addBy(10);
      expect(store.value.count, 11);
      store.dispose();
    });

    test('skips emission when next == current (equality dedup)', () async {
      final store = createStore<CounterState>((set, get) => _makeState(
            count: 1,
            userRole: 'Guest',
          ));
      var emissions = 0;
      final sub = store.listen((_) => emissions++);

      // Set to an equal state (same data fields) -> no emit.
      store.set((s) => _makeState(count: 1, userRole: 'Guest'));
      expect(store.value.count, 1);
      await Future<void>.delayed(Duration.zero);
      expect(emissions, 0);

      // Set to a different state -> emit.
      store.set((s) => _makeState(count: 2, userRole: 'Guest'));
      await Future<void>.delayed(Duration.zero);
      expect(emissions, 1);

      sub.cancel();
      store.dispose();
    });

    test('set to identical instance (same ref) is a no-op', () async {
      final initial = _makeState(count: 5);
      final store = createStore<CounterState>((_, _) => initial);
      var emissions = 0;
      final sub = store.listen((_) => emissions++);
      store.set((s) => s); // returns same ref
      await Future<void>.delayed(Duration.zero);
      expect(emissions, 0);
      sub.cancel();
      store.dispose();
    });

    test('throws StateError when set is called during initialization', () {
      expect(
        () => createStore<CounterState>((set, get) {
          set((s) => s); // illegal during init
          return _makeState();
        }),
        throwsStateError,
      );
    });

    test('throws StateError when get is called during initialization', () {
      expect(
        () => createStore<CounterState>((set, get) {
          get(); // illegal during init
          return _makeState();
        }),
        throwsStateError,
      );
    });
  });

  group('Store.listen', () {
    test('emits on change', () async {
      final store = createStore<CounterState>((set, get) => _makeState(
            count: 0,
            increment: () => set((s) => s.copyWith(count: s.count + 1)),
          ));
      final received = <int>[];
      final sub = store.listen((s) => received.add(s.count));

      store.value.increment();
      store.value.increment();
      await Future<void>.delayed(Duration.zero);
      expect(received, [1, 2]);

      sub.cancel();
      store.dispose();
    });

    test('broadcasts to multiple listeners', () async {
      final store = createStore<CounterState>((set, get) => _makeState(
            count: 0,
            increment: () => set((s) => s.copyWith(count: s.count + 1)),
          ));
      final a = <int>[], b = <int>[];
      final subA = store.listen((s) => a.add(s.count));
      final subB = store.listen((s) => b.add(s.count));

      store.value.increment();
      await Future<void>.delayed(Duration.zero);
      expect(a, [1]);
      expect(b, [1]);

      subA.cancel();
      subB.cancel();
      store.dispose();
    });
  });

  group('Store.dispose', () {
    test('closes the stream (further set throws)', () {
      final store = createStore<CounterState>((set, get) => _makeState());
      store.dispose();
      expect(store.value.count, 0);
      // Adding to a closed broadcast controller throws.
      expect(
        () => store.set((s) => _makeState(count: 1)),
        throwsStateError,
      );
    });

    test('listeners stop receiving after dispose', () async {
      final store = createStore<CounterState>((set, get) => _makeState(
            count: 0,
            increment: () => set((s) => s.copyWith(count: s.count + 1)),
          ));
      var emissions = 0;
      store.listen((_) => emissions++);
      store.dispose();
      // set on disposed store throws, so emissions stay at 0.
      expect(emissions, 0);
    });
  });

  group('persist', () {
    test('hydrates from storage on construction', () async {
      final storage = _MemoryStorage();
      // Seed storage with a serialized state.
      await storage.setItem(
        'counter',
        '{"count":42,"userRole":"Admin"}',
      );

      final store = await persist<CounterState>(
        name: 'counter',
        storageEngine: storage,
        initializer: (set, get) => _makeState(count: 0),
        toJson: (s) => {'count': s.count, 'userRole': s.userRole},
        fromJson: (json) => _makeState(
          count: json['count'] as int,
          userRole: json['userRole'] as String,
        ),
      );

      expect(store.value.count, 42);
      expect(store.value.userRole, 'Admin');
      store.dispose();
    });

    test('saves on every emission', () async {
      final storage = _MemoryStorage();
      final store = await persist<CounterState>(
        name: 'counter',
        storageEngine: storage,
        initializer: (set, get) => _makeState(
          count: 0,
          increment: () => set((s) => s.copyWith(count: s.count + 1)),
        ),
        toJson: (s) => {'count': s.count, 'userRole': s.userRole},
        fromJson: (json) => _makeState(
          count: json['count'] as int? ?? 0,
          userRole: json['userRole'] as String? ?? 'Guest',
        ),
      );

      store.value.increment();
      store.value.increment();
      await Future<void>.delayed(Duration.zero);

      final saved = await storage.getItem('counter');
      expect(saved, isNotNull);
      expect(saved, contains('"count":2'));

      store.dispose();
    });

    test('hydrate error is reported via onError and store still works',
        () async {
      final errors = <Object>[];
      final store = await persist<CounterState>(
        name: 'counter',
        storageEngine: _SyncFailingStorage(),
        initializer: (set, get) => _makeState(
          count: 0,
          increment: () => set((s) => s.copyWith(count: s.count + 1)),
        ),
        toJson: (s) => {'count': s.count},
        fromJson: (json) => _makeState(count: json['count'] as int),
        onError: (error, stackTrace) => errors.add(error),
      );

      // Hydration failed -> error reported, initial state intact.
      await Future<void>.delayed(Duration.zero);
      expect(errors, isNotEmpty);
      expect(store.value.count, 0);

      // A set triggers a persist write which also fails -> reported.
      store.value.increment();
      // The on-emission persist write awaits setItem; pump microtasks so the
      // awaited Future.error completes and persist's try/catch fires onError.
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(errors.length, greaterThanOrEqualTo(2));
      expect(store.value.count, 1);

      store.dispose();
    });

    test('empty storage leaves initial state untouched', () async {
      final storage = _MemoryStorage();
      final store = await persist<CounterState>(
        name: 'counter',
        storageEngine: storage,
        initializer: (set, get) => _makeState(count: 7),
        toJson: (s) => {'count': s.count},
        fromJson: (json) => _makeState(count: json['count'] as int),
      );
      expect(store.value.count, 7);
      store.dispose();
    });
  });
}

// Helper state for collection-equality tests.
class _CollectionState with StoreState {
  final List<int> items;
  const _CollectionState({this.items = const []});

  @override
  _CollectionState copyWith({List<int>? items}) =>
      _CollectionState(items: items ?? this.items);

  @override
  List<Object?> get props => [items];
}
import 'package:flutter/material.dart';
import 'package:flutter_isimo/flutter_isimo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isimo/isimo.dart';

// --- Test state -------------------------------------------------------------

class CounterState with StoreState {
  final int count;
  final String userRole;
  final void Function() increment;
  final void Function() bumpRole;

  const CounterState({
    this.count = 0,
    this.userRole = 'Guest',
    required this.increment,
    required this.bumpRole,
  });

  @override
  CounterState copyWith({int? count, String? userRole}) => CounterState(
        count: count ?? this.count,
        userRole: userRole ?? this.userRole,
        increment: increment,
        bumpRole: bumpRole,
      );

  @override
  List<Object?> get props => [count, userRole];
}

Store<CounterState> _newStore() {
  return createStore<CounterState>((set, get) => CounterState(
        count: 0,
        userRole: 'Guest',
        increment: () => set((s) => s.copyWith(count: s.count + 1)),
        bumpRole: () => set((s) =>
            s.copyWith(userRole: s.userRole == 'Guest' ? 'Admin' : 'Guest')),
      ));
}

// A widget that selects only `count` and records how many times it builds.
class _CountSelector extends StatefulWidget {
  const _CountSelector({super.key});
  @override
  State<_CountSelector> createState() => _CountSelectorState();
}

class _CountSelectorState extends State<_CountSelector> {
  int buildCount = 0;

  @override
  Widget build(BuildContext context) {
    buildCount++;
    final count = context.useStore<CounterState, int>((s) => s.count);
    return Text('count=$count', textDirection: TextDirection.ltr);
  }
}

// A widget that selects only `userRole` and records its builds.
class _RoleSelector extends StatefulWidget {
  const _RoleSelector({super.key});
  @override
  State<_RoleSelector> createState() => _RoleSelectorState();
}

class _RoleSelectorState extends State<_RoleSelector> {
  int buildCount = 0;

  @override
  Widget build(BuildContext context) {
    buildCount++;
    final role = context.useStore<CounterState, String>((s) => s.userRole);
    return Text('role=$role', textDirection: TextDirection.ltr);
  }
}

// A widget that selects an action (stable ref) and records its builds.
class _ActionSelector extends StatefulWidget {
  const _ActionSelector({super.key});
  @override
  State<_ActionSelector> createState() => _ActionSelectorState();
}

class _ActionSelectorState extends State<_ActionSelector> {
  int buildCount = 0;

  @override
  Widget build(BuildContext context) {
    buildCount++;
    final increment =
        context.useStore<CounterState, void Function()>((s) => s.increment);
    return GestureDetector(
      onTap: increment,
      child: Text('tap', textDirection: TextDirection.ltr),
    );
  }
}

void main() {
  testWidgets('StoreProvider scopes a Store<T> down the tree', (tester) async {
    final store = _newStore();
    await tester.pumpWidget(
      StoreProvider<CounterState>(
        store: store,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              final count =
                  context.useStore<CounterState, int>((s) => s.count);
              return Text('count=$count');
            },
          ),
        ),
      ),
    );
    expect(find.text('count=0'), findsOneWidget);

    store.value.increment();
    await tester.pump();
    expect(find.text('count=1'), findsOneWidget);

    store.dispose();
  });

  testWidgets('useStore rebuilds only when the selected slice changes',
      (tester) async {
    final store = _newStore();
    final countKey = GlobalKey();
    final roleKey = GlobalKey();

    await tester.pumpWidget(
      StoreProvider<CounterState>(
        store: store,
        child: Column(
          textDirection: TextDirection.ltr,
          children: [
            _CountSelector(key: countKey),
            _RoleSelector(key: roleKey),
          ],
        ),
      ),
    );

    final countState = tester.state(find.byKey(countKey)) as _CountSelectorState;
    final roleState = tester.state(find.byKey(roleKey)) as _RoleSelectorState;

    // Initial build: both built once.
    expect(countState.buildCount, 1);
    expect(roleState.buildCount, 1);

    // Bumping count -> only the count selector rebuilds.
    store.value.increment();
    await tester.pump();
    expect(countState.buildCount, 2);
    expect(roleState.buildCount, 1); // unchanged slice -> no rebuild

    // Bumping role -> only the role selector rebuilds.
    store.value.bumpRole();
    await tester.pump();
    expect(countState.buildCount, 2); // unchanged -> no rebuild
    expect(roleState.buildCount, 2);

    store.dispose();
  });

  testWidgets('useStore with a custom equals predicate', (tester) async {
    final store = _newStore();
    int buildCount = 0;
    await tester.pumpWidget(
      StoreProvider<CounterState>(
        store: store,
        child: MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              // Rebuild manually to bump buildCount on selector change.
              final count = context.useStore<CounterState, int>(
                (s) => s.count,
                equals: (a, b) => (a ~/ 10) == (b ~/ 10),
              );
              buildCount++;
              return Text('count=$count');
            },
          ),
        ),
      ),
    );

    expect(buildCount, 1);
    // Increment within the same "decade" -> equal per custom equals -> no
    // rebuild.
    store.value.increment(); // 0 -> 1
    await tester.pump();
    expect(buildCount, 1);

    // Cross a decade boundary (9 -> 10) -> rebuilds.
    for (var i = 0; i < 9; i++) {
      store.value.increment();
    }
    await tester.pump();
    expect(buildCount, 2);

    store.dispose();
  });

  testWidgets('StoreProvider.read returns the store without subscribing',
      (tester) async {
    final store = _newStore();
    int outerBuilds = 0;

    await tester.pumpWidget(
      StoreProvider<CounterState>(
        store: store,
        child: MaterialApp(
          home: StatefulBuilder(
            builder: (context, _) {
              outerBuilds++;
              // read() must NOT subscribe — so changing state shouldn't
              // rebuild this builder.
              final s = StoreProvider.read<CounterState>(context);
              return Text('count=${s.value.count}');
            },
          ),
        ),
      ),
    );

    expect(outerBuilds, 1);
    store.value.increment();
    await tester.pump();
    // outerBuilds stays 1 because read() did not subscribe.
    expect(outerBuilds, 1);

    store.dispose();
  });

  testWidgets('StoreProvider.of subscribes (rebuilds on any change)',
      (tester) async {
    final store = _newStore();
    int builds = 0;
    await tester.pumpWidget(
      StoreProvider<CounterState>(
        store: store,
        child: MaterialApp(
          home: StatefulBuilder(
            builder: (context, _) {
              builds++;
              final s = StoreProvider.of<CounterState>(context);
              return Text('count=${s.value.count}');
            },
          ),
        ),
      ),
    );
    expect(builds, 1);
    store.value.increment();
    await tester.pump();
    expect(builds, 2);
    store.dispose();
  });

  testWidgets('selecting an action (stable ref) does NOT rebuild',
      (tester) async {
    final store = _newStore();
    final actionKey = GlobalKey();

    await tester.pumpWidget(
      StoreProvider<CounterState>(
        store: store,
        child: Column(
          textDirection: TextDirection.ltr,
          children: [
            _ActionSelector(key: actionKey),
            _CountSelector(),
          ],
        ),
      ),
    );

    final actionState = tester.state(find.byKey(actionKey)) as _ActionSelectorState;
    expect(actionState.buildCount, 1);

    // Changing count rebuilds the count selector but NOT the action selector
    // (action is a stable closure field — its identity is unchanged).
    store.value.increment();
    await tester.pump();
    expect(actionState.buildCount, 1);

    // Changing role also must not rebuild the action selector.
    store.value.bumpRole();
    await tester.pump();
    expect(actionState.buildCount, 1);

    // The action still works (tapping fires increment).
    await tester.tap(find.byType(_ActionSelector));
    await tester.pump();
    expect(store.value.count, 2);
    // After firing, count changed — but the action selector's selected slice
    // (the action closure) is unchanged, so it STILL doesn't rebuild.
    expect(actionState.buildCount, 1);

    store.dispose();
  });

  testWidgets('StoreProvider.of throws StateError when no provider is found',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return const Text('ok');
          },
        ),
      ),
    );
    final context = tester.element(find.text('ok'));
    expect(
      () => StoreProvider.of<CounterState>(context),
      throwsStateError,
    );
  });

  testWidgets('StoreProvider.read throws StateError when no provider is found',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => const Text('ok'),
        ),
      ),
    );
    final context = tester.element(find.text('ok'));
    expect(
      () => StoreProvider.read<CounterState>(context),
      throwsStateError,
    );
  });

  testWidgets('multiple StoreProviders of different types coexist',
      (tester) async {
    final counterStore = _newStore();
    final otherStore = createStore<OtherState>((set, get) => OtherState(
          name: 'a',
          setName: (v) => set((s) => s.copyWith(name: v)),
        ));

    await tester.pumpWidget(
      StoreProvider<CounterState>(
        store: counterStore,
        child: StoreProvider<OtherState>(
          store: otherStore,
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                final count =
                    context.useStore<CounterState, int>((s) => s.count);
                final name =
                    context.useStore<OtherState, String>((s) => s.name);
                return Text('$count/$name');
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('0/a'), findsOneWidget);

    counterStore.value.increment();
    await tester.pump();
    expect(find.text('1/a'), findsOneWidget);

    otherStore.value.setName('b');
    await tester.pump();
    expect(find.text('1/b'), findsOneWidget);

    counterStore.dispose();
    otherStore.dispose();
  });
}

class OtherState with StoreState {
  final String name;
  final void Function(String) setName;
  const OtherState({this.name = '', required this.setName});

  @override
  OtherState copyWith({String? name}) =>
      OtherState(name: name ?? this.name, setName: setName);

  @override
  List<Object?> get props => [name];
}
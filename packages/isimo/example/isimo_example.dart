import 'package:isimo/isimo.dart';

// An immutable state class with colocated actions. `final` closure fields
// give actions stable identity (selecting them never rebuilds in Flutter).
class CounterState with StoreState {
  final int count;
  final void Function() increment;
  final void Function(int amount) addBy;

  const CounterState({
    this.count = 0,
    required this.increment,
    required this.addBy,
  });

  @override
  CounterState copyWith({int? count}) => CounterState(
        count: count ?? this.count,
        increment: increment,
        addBy: addBy,
      );

  // Data fields only — actions are stable refs, omitted from equality.
  @override
  List<Object?> get props => [count];
}

void main() {
  final counterStore = createStore<CounterState>((set, get) => CounterState(
        count: 0,
        increment: () => set((s) => s.copyWith(count: s.count + 1)),
        addBy: (amount) => set((s) => s.copyWith(count: s.count + amount)),
      ));

  // Subscribe in pure Dart (no Flutter required).
  final sub = counterStore.listen((s) => print('count changed -> ${s.count}'));

  counterStore.value.increment(); // prints: count changed -> 1
  counterStore.value.addBy(5); // prints: count changed -> 6
  print('final count: ${counterStore.value.count}'); // final count: 6

  sub.cancel();
  counterStore.dispose();
}
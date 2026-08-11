import 'package:flutter/material.dart';
import 'package:flutter_isimo/flutter_isimo.dart';
import 'package:isimo/isimo.dart';

// Immutable state with colocated actions. `final` closure fields give actions
// stable identity — selecting them via `useStore` never rebuilds.
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

// A single store instance scoped into the tree via StoreProvider.
final counterStore = createStore<CounterState>((set, get) => CounterState(
      count: 0,
      increment: () => set((s) => s.copyWith(count: s.count + 1)),
      addBy: (amount) => set((s) => s.copyWith(count: s.count + amount)),
    ));

void main() {
  runApp(
    StoreProvider<CounterState>(
      store: counterStore,
      child: const MaterialApp(home: CounterPage()),
    ),
  );
}

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Selecting a value slice — rebuilds only when `count` changes.
    final count = context.useStore<CounterState, int>((s) => s.count);
    // Selecting an action — stable ref, never rebuilds.
    final increment =
        context.useStore<CounterState, void Function()>((s) => s.increment);
    final addBy =
        context.useStore<CounterState, void Function(int)>((s) => s.addBy);

    return Scaffold(
      appBar: AppBar(title: const Text('isimo counter')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Count'),
            Text('$count', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: increment,
              child: const Text('Increment'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => addBy(10),
              child: const Text('Add 10'),
            ),
          ],
        ),
      ),
    );
  }
}
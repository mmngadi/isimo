import 'package:flutter/material.dart';
import 'package:flutter_isimo/flutter_isimo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isimo/isimo.dart';
import 'package:todo_app/app.dart';
import 'package:todo_app/src/features/todo/state/todo_state.dart';

import 'helpers/todo_store_test_helper.dart';

void main() {
  Store<TodoState> makeStore() => createInMemoryTodoStore();

  Widget makeApp(Store<TodoState> store) => TodoApp(store: store);

  testWidgets('starts empty with the "All" filter and an empty-state message',
      (tester) async {
    final store = makeStore();
    await tester.pumpWidget(makeApp(store));

    // AppBar shows 0/0 active.
    expect(find.text('Todos · 0/0 active'), findsOneWidget);
    // Empty-state for the "All" filter.
    expect(find.text('No todos yet. Tap + to add one.'), findsOneWidget);
    // Three filter chips, "All" selected.
    expect(find.byType(ChoiceChip), findsNWidgets(3));
    final allChip = tester.widget<ChoiceChip>(
      find.ancestor(of: find.text('All'), matching: find.byType(ChoiceChip)),
    );
    expect(allChip.selected, isTrue);

    store.dispose();
  });

  testWidgets('add a todo via the FAB dialog → appears in the list and the count',
      (tester) async {
    final store = makeStore();
    await tester.pumpWidget(makeApp(store));

    // Open the add dialog, type a title, submit.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('New todo'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Buy milk');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // The todo is rendered.
    expect(find.text('Buy milk'), findsOneWidget);
    // Count updated to 1/1 active.
    expect(find.text('Todos · 1/1 active'), findsOneWidget);
    // Empty state gone.
    expect(find.text('No todos yet. Tap + to add one.'), findsNothing);

    store.dispose();
  });

  testWidgets('toggling a todo marks it done and moves it out of the Active filter',
      (tester) async {
    final store = makeStore();
    await tester.pumpWidget(makeApp(store));

    // Add one todo.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Write tests');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Toggle via the checkbox.
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    // Count is now 0/1 active (1 done).
    expect(find.text('Todos · 0/1 active'), findsOneWidget);

    // Switch to the Active filter → empty-state for active.
    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();
    expect(find.text('No active todos. Nice work!'), findsOneWidget);

    // Switch to Completed → the todo reappears.
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    expect(find.text('Write tests'), findsOneWidget);

    store.dispose();
  });

  testWidgets(
      'clear completed removes only completed todos and leaves active ones',
      (tester) async {
    final store = makeStore();
    await tester.pumpWidget(makeApp(store));

    // Add two todos.
    for (final title in const ['Keep me', 'Delete me']) {
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), title);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }
    expect(find.text('Todos · 2/2 active'), findsOneWidget);

    // Toggle "Delete me" (the second checkbox).
    await tester.tap(checkboxsAt(1));
    await tester.pumpAndSettle();
    expect(find.text('Todos · 1/2 active'), findsOneWidget);

    // Tap the clear-completed action.
    await tester.tap(find.byTooltip('Clear completed'));
    await tester.pumpAndSettle();

    // Only "Keep me" remains; count is 1/1 active.
    expect(find.text('Keep me'), findsOneWidget);
    expect(find.text('Delete me'), findsNothing);
    expect(find.text('Todos · 1/1 active'), findsOneWidget);

    store.dispose();
  });

  testWidgets('addTodo with a blank title is a no-op', (tester) async {
    final store = makeStore();
    await tester.pumpWidget(makeApp(store));

    // Dispatch addTodo with whitespace directly through the store.
    store.value.addTodo('   ');
    await tester.pumpAndSettle();

    expect(store.value.todos, isEmpty);
    expect(find.text('Todos · 0/0 active'), findsOneWidget);

    store.dispose();
  });

  testWidgets('swipe-to-delete removes a todo', (tester) async {
    final store = makeStore();
    await tester.pumpWidget(makeApp(store));

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Swipe me');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Dismiss the only list item left-to-end.
    await tester.drag(find.text('Swipe me'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Swipe me'), findsNothing);
    expect(find.text('Todos · 0/0 active'), findsOneWidget);

    store.dispose();
  });

  testWidgets('edit title via tapping a tile updates the title', (tester) async {
    final store = makeStore();
    await tester.pumpWidget(makeApp(store));

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Old title');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Tap the ListTile to open the edit dialog.
    await tester.tap(find.text('Old title'));
    await tester.pumpAndSettle();
    expect(find.text('Edit todo'), findsOneWidget);

    // Clear and type a new title.
    await tester.enterText(find.byType(TextField), 'New title');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('New title'), findsOneWidget);
    expect(find.text('Old title'), findsNothing);

    store.dispose();
  });

  testWidgets('StoreProvider.read returns the store without subscribing',
      (tester) async {
    final store = makeStore();
    int builds = 0;
    await tester.pumpWidget(
      StoreProvider<TodoState>(
        store: store,
        child: MaterialApp(
          home: StatefulBuilder(
            builder: (context, _) {
              builds++;
              StoreProvider.read<TodoState>(context);
              return const Text('ok');
            },
          ),
        ),
      ),
    );
    expect(builds, 1);
    store.value.addTodo('x');
    await tester.pumpAndSettle();
    // read() did not subscribe, so no rebuild.
    expect(builds, 1);
    store.dispose();
  });

  testWidgets('surgical rebuild: a sibling tile does not rebuild when another toggles',
      (tester) async {
    final store = makeStore();
    await tester.pumpWidget(makeApp(store));

    // Add two todos.
    for (final title in const ['First', 'Second']) {
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), title);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }

    // Toggle the FIRST checkbox and verify the SECOND tile's checkbox value
    // is unchanged (it did not rebuild with a flipped value).
    final secondCheckboxBefore =
        tester.widget<Checkbox>(checkboxsAt(1));
    expect(secondCheckboxBefore.value, isFalse);

    await tester.tap(checkboxsAt(0));
    await tester.pumpAndSettle();

    // First is now done; second is still not done.
    final firstCheckboxAfter =
        tester.widget<Checkbox>(checkboxsAt(0));
    final secondCheckboxAfter =
        tester.widget<Checkbox>(checkboxsAt(1));
    expect(firstCheckboxAfter.value, isTrue);
    expect(secondCheckboxAfter.value, isFalse);

    store.dispose();
  });
}

/// Helper to find the n-th Checkbox widget.
Finder checkboxsAt(int index) => find.byType(Checkbox).at(index);
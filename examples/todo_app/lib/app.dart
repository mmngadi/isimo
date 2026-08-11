import 'package:flutter/material.dart';
import 'package:flutter_isimo/flutter_isimo.dart';
import 'package:isimo/isimo.dart';
import 'package:todo_app/src/features/todo/presentation/todo_screen.dart';
import 'package:todo_app/src/features/todo/state/todo_state.dart';

/// App root widget. Scopes the todo [Store] into the tree via
/// [StoreProvider] and renders the [TodoScreen].
class TodoApp extends StatelessWidget {
  const TodoApp({super.key, required this.store});

  final Store<TodoState> store;

  @override
  Widget build(BuildContext context) {
    return StoreProvider<TodoState>(
      store: store,
      child: MaterialApp(
        title: 'isimo Todos',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF3949AB),
          useMaterial3: true,
        ),
        home: const TodoScreen(),
      ),
    );
  }
}
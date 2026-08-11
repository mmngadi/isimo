import 'package:flutter/material.dart';
import 'package:todo_app/app.dart';
import 'package:todo_app/src/features/todo/state/todo_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await createTodoStore();
  runApp(TodoApp(store: store));
}
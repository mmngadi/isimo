// Flutter bindings for the isimo state management engine.
// Bridges pure Dart `Store<T>` to Flutter's element tree with surgical
// rebuilds via a custom InheritedElement that gates each dependent by its
// selector equality (NOT InheritedNotifier, which broadcasts to all).
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:isimo/isimo.dart';

/// Scopes a [Store<T>] down the widget tree.
///
/// Subclass to build domain-specific providers (e.g. `CounterProvider`).
/// Use [of] for a subscribing accessor (rebuilds on any change) or [read]
/// for a non-subscribing accessor (lifecycle hooks, grabbing the handle).
class StoreProvider<T> extends StatefulWidget {
  /// The store scoped by this provider.
  final Store<T> store;

  /// The widget subtree below this provider.
  final Widget child;

  const StoreProvider({
    super.key,
    required this.store,
    required this.child,
  });

  /// Subscribing accessor — the calling widget rebuilds on any store change.
  ///
  /// Throws a [StateError] if no [StoreProvider<T>] is found above in the
  /// tree.
  static Store<T> of<T>(BuildContext context) {
    // Register a dependency with a `_Dep` aspect selecting the whole state
    // so the custom InheritedElement rebuilds this dependent on any state
    // change (routed through the store's stream listener). A bare
    // `dependOnInheritedWidgetOfExactType` with no aspect would only fire on
    // store *replacement* (updateShouldNotify), not on state emissions.
    final dep = _Dep((s) => s, null);
    final scope =
        context.dependOnInheritedWidgetOfExactType<_InheritedStore<T>>(
      aspect: dep,
    );
    if (scope == null) {
      throw StateError(
        'No StoreProvider<$T> found in the current BuildContext.\n'
        'Ensure a StoreProvider<$T> is placed above this widget in the tree.',
      );
    }
    return scope.store;
  }

  /// Non-subscribing accessor — for lifecycle hooks (`initState`) where
  /// `useStore` is illegal, or to grab the [Store<T>] handle itself.
  ///
  /// Throws a [StateError] if no [StoreProvider<T>] is found above in the
  /// tree.
  static Store<T> read<T>(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<_InheritedStore<T>>();
    if (scope == null) {
      throw StateError(
        'No StoreProvider<$T> found in the current BuildContext.\n'
        'Ensure a StoreProvider<$T> is placed above this widget in the tree.',
      );
    }
    return scope.store;
  }

  @override
  State<StoreProvider<T>> createState() => _StoreProviderState<T>();
}

class _StoreProviderState<T> extends State<StoreProvider<T>> {
  @override
  Widget build(BuildContext context) => _InheritedStore<T>(
        store: widget.store,
        child: widget.child,
      );
}

class _InheritedStore<T> extends InheritedWidget {
  final Store<T> store;
  const _InheritedStore({required this.store, required super.child});

  @override
  InheritedElement createElement() => _StoreElement<T>(this);

  @override
  bool updateShouldNotify(covariant _InheritedStore<T> old) =>
      store != old.store;
}

/// A dependent's selector + equality predicate + last emitted value.
///
/// Reused across rebuilds via [InheritedElement.updateDependencies] so change
/// detection stays stable (a fresh [_Dep] is created each build — we carry
/// `lastValue` over from the previous registration). Types are erased to
/// `Object?` here; the [useStore] extension re-introduces typing at the
/// call boundary with safe casts.
class _Dep {
  final Object? Function(Object?) selector;
  final bool Function(Object?, Object?)? equals;
  Object? lastValue;
  bool hasLastValue = false;

  _Dep(this.selector, this.equals);
}

/// Custom [InheritedElement] that tracks each dependent's selector + last
/// result and only [markNeedsBuild]s a dependent when its selected slice
/// changes. This is what gives isimo surgical rebuilds instead of the
/// broadcast behavior of [InheritedNotifier].
///
/// A single element may register multiple selectors (e.g. a widget calling
/// `useStore` for several slices); each is tracked independently and the
/// element rebuilds when any of its selected slices changes.
class _StoreElement<T> extends InheritedElement {
  _StoreElement(super.widget);

  final Map<Element, Set<_Dep>> _deps = {};
  late final StreamSubscription<T> _sub;

  Store<T> get store => (widget as _InheritedStore<T>).store;

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    _sub = store.listen((_) => _onStoreChanged());
  }

  void _onStoreChanged() {
    final value = store.value;
    for (final entry in _deps.entries) {
      final element = entry.key;
      for (final dep in entry.value) {
        final next = dep.selector(value);
        // `equals` returns true when the two slices are considered equal (no
        // change); default equality is `==`. So `changed = !equal`.
        final equal =
            dep.equals?.call(dep.lastValue, next) ?? dep.lastValue == next;
        final changed = !dep.hasLastValue || !equal;
        if (changed) {
          dep.lastValue = next;
          dep.hasLastValue = true;
          element.markNeedsBuild();
        }
      }
    }
  }

  @override
  void updateDependencies(Element dependent, Object? aspect) {
    super.updateDependencies(dependent, aspect);
    if (aspect is! _Dep) return;
    // A widget may call `useStore` multiple times in one build; collect every
    // dep for the same element. Each dep is seeded with the current selection
    // so the first store change is compared against the initial value rather
    // than blindly treated as a change (which would ignore `equals`/`==`).
    aspect.lastValue = aspect.selector(store.value);
    aspect.hasLastValue = true;
    final set = _deps.putIfAbsent(dependent, () => {});
    // Replace any prior dep for the same selector identity so we don't
    // accumulate stale registrations across rebuilds. Inline closures won't
    // match by identity, so they accumulate — but `markNeedsBuild` is
    // idempotent and stale entries are cleaned when the element rebuilds
    // (it re-registers its current set of selectors).
    set.removeWhere((d) => identical(d.selector, aspect.selector));
    set.add(aspect);
  }

  @override
  void unmount() {
    _sub.cancel();
    super.unmount();
  }
}

/// Flutter [BuildContext] extension for isimo selector subscriptions.
///
/// [useStore] is the single context hook: it selects a slice [R] from
/// [Store<T>] and rebuilds the calling widget only when the slice changes
/// (default `==`, or a custom [equals]).
extension IsimoFlutterContextX on BuildContext {
  /// Selects a slice [R] from [Store<T>] and rebuilds this widget only when
  /// the slice changes (`==` by default, or custom [equals]).
  ///
  /// The selector should be a stable reference (top-level/static function or
  /// `final` closure) for the most accurate change detection. Selecting an
  /// action (a `final` closure field) never rebuilds because actions are
  /// stable references.
  R useStore<T, R>(R Function(T) selector, {bool Function(R, R)? equals}) {
    final dep = _Dep(
      (s) => selector(s as T),
      equals == null ? null : (a, b) => equals(a as R, b as R),
    );
    final inherited =
        dependOnInheritedWidgetOfExactType<_InheritedStore<T>>(aspect: dep)!;
    return selector(inherited.store.value);
  }
}
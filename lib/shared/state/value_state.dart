import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reemplazo del viejo `StateProvider` (legacy en Riverpod 3): un Notifier
/// mínimo que guarda un valor mutable desde la UI.
class ValueState<T> extends Notifier<T> {
  ValueState(this._initial);
  final T _initial;

  @override
  T build() => _initial;

  void set(T value) => state = value;

  void update(T Function(T current) transform) => state = transform(state);
}

NotifierProvider<ValueState<T>, T> valueStateProvider<T>(T initial) =>
    NotifierProvider<ValueState<T>, T>(() => ValueState(initial));

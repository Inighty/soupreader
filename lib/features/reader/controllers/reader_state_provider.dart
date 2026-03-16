import 'package:flutter/cupertino.dart';

import 'reader_state_manager.dart';

/// InheritedNotifier that provides the [ReaderStateManager] to the entire
/// reader widget subtree.
///
/// Child widgets access it via `ReaderStateProvider.of(context)`.
/// They automatically rebuild when [ReaderStateManager.notifyListeners]
/// fires.
class ReaderStateProvider extends InheritedNotifier<ReaderStateManager> {
  const ReaderStateProvider({
    super.key,
    required ReaderStateManager manager,
    required super.child,
  }) : super(notifier: manager);

  /// Obtains the nearest [ReaderStateManager] from the widget tree.
  ///
  /// This registers a dependency: the calling widget rebuilds when the
  /// manager notifies.
  static ReaderStateManager of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<ReaderStateProvider>();
    assert(provider != null, 'No ReaderStateProvider found in context');
    return provider!.notifier!;
  }

  /// Reads the [ReaderStateManager] without registering a dependency.
  ///
  /// Use this when you need the manager for a one-off action (e.g. in an
  /// onPressed callback) but do NOT want the widget to rebuild on changes.
  static ReaderStateManager read(BuildContext context) {
    final provider = context
        .getInheritedWidgetOfExactType<ReaderStateProvider>();
    assert(provider != null, 'No ReaderStateProvider found in context');
    return provider!.notifier!;
  }
}

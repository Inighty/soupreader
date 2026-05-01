import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import 'package:soupreader/core/database/repositories/source_repository.dart';
import 'package:soupreader/features/source/models/book_source.dart';

class SourceListSelectionController {
  SourceListSelectionController({
    required this.sourceRepo,
    required this.listScrollController,
    required this.listViewportKey,
    required this.selectedUrls,
    required this.itemKeyByUrl,
    required this.isManualReorderEnabled,
    required this.isSortAscending,
  });

  final SourceRepository sourceRepo;
  final ScrollController listScrollController;
  final GlobalKey listViewportKey;
  final Set<String> selectedUrls;
  final Map<String, GlobalKey> itemKeyByUrl;
  final bool Function() isManualReorderEnabled;
  final bool Function() isSortAscending;

  bool _dragSelecting = false;
  bool _dragSelectValue = true;
  int _dragLastIndex = -1;

  GlobalKey itemKeyForUrl(String url) {
    return itemKeyByUrl.putIfAbsent(
      url,
      () => GlobalKey(debugLabel: 'source-item-$url'),
    );
  }

  Future<void> onReorderVisible(
    List<BookSource> visible,
    int oldIndex,
    int newIndex,
  ) async {
    if (!isManualReorderEnabled() || visible.isEmpty) return;
    if (oldIndex < 0 || oldIndex >= visible.length) return;
    var targetIndex = newIndex;
    if (oldIndex < targetIndex) {
      targetIndex -= 1;
    }
    if (targetIndex < 0 || targetIndex >= visible.length) return;
    if (oldIndex == targetIndex) return;

    final start = math.min(oldIndex, targetIndex);
    final end = math.max(oldIndex, targetIndex);
    final originalOrders =
        visible.sublist(start, end + 1).map((source) => source.customOrder).toList();

    final reordered = visible.toList(growable: true);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(targetIndex, moved);

    final affectedOrders = <int>{};
    var hasDuplicateOrderInAffectedRange = false;
    for (var index = start; index <= end; index++) {
      if (!affectedOrders.add(reordered[index].customOrder)) {
        hasDuplicateOrderInAffectedRange = true;
        break;
      }
    }
    if (hasDuplicateOrderInAffectedRange) {
      final normalized = reordered
          .asMap()
          .entries
          .map(
            (entry) => entry.value.copyWith(
              customOrder: isSortAscending() ? entry.key : -entry.key,
            ),
          )
          .toList(growable: false);
      await sourceRepo.addSources(normalized);
      return;
    }

    final updated = <BookSource>[];
    for (var index = start; index <= end; index++) {
      final source = reordered[index];
      final nextOrder = originalOrders[index - start];
      if (source.customOrder == nextOrder) continue;
      updated.add(source.copyWith(customOrder: nextOrder));
    }
    if (updated.isEmpty) return;
    await sourceRepo.addSources(updated);
  }

  bool startDragSelection(List<BookSource> visible, int index) {
    if (index < 0 || index >= visible.length) return false;
    final url = visible[index].bookSourceUrl;
    _dragSelecting = true;
    _dragSelectValue = !selectedUrls.contains(url);
    _dragLastIndex = -1;
    _applyDragSelectionAt(visible, index);
    return true;
  }

  bool updateDragSelectionByGlobal(
    List<BookSource> visible,
    Offset globalPosition,
  ) {
    if (!_dragSelecting) return false;
    final hitIndex = hitTestVisibleIndexByGlobal(visible, globalPosition);
    if (hitIndex == null || hitIndex == _dragLastIndex) return false;
    _applyDragSelectionAt(visible, hitIndex);
    return true;
  }

  void autoScrollForDragSelection(
    List<BookSource> visible,
    Offset globalPosition,
    VoidCallback onSelectionChanged,
  ) {
    if (!_dragSelecting || !listScrollController.hasClients) return;
    final viewportContext = listViewportKey.currentContext;
    if (viewportContext == null) return;
    final viewportObject = viewportContext.findRenderObject();
    if (viewportObject is! RenderBox ||
        !viewportObject.hasSize ||
        !viewportObject.attached) {
      return;
    }
    final localOffset = viewportObject.globalToLocal(globalPosition);
    final viewportHeight = viewportObject.size.height;
    if (viewportHeight <= 0) return;

    const edgePadding = 64.0;
    const maxStep = 26.0;
    var delta = 0.0;
    if (localOffset.dy < edgePadding) {
      final ratio =
          ((edgePadding - localOffset.dy) / edgePadding).clamp(0.0, 1.0);
      delta = -maxStep * ratio;
    } else if (localOffset.dy > viewportHeight - edgePadding) {
      final ratio =
          ((localOffset.dy - (viewportHeight - edgePadding)) / edgePadding)
              .clamp(0.0, 1.0);
      delta = maxStep * ratio;
    }
    if (delta == 0) return;

    final position = listScrollController.position;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < 0.5) return;
    listScrollController.jumpTo(target);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_dragSelecting) return;
      if (updateDragSelectionByGlobal(visible, globalPosition)) {
        onSelectionChanged();
      }
    });
  }

  bool endDragSelection() {
    if (!_dragSelecting) return false;
    _dragSelecting = false;
    _dragLastIndex = -1;
    return true;
  }

  int? hitTestVisibleIndexByGlobal(
    List<BookSource> visible,
    Offset globalPosition,
  ) {
    for (var index = 0; index < visible.length; index++) {
      final context = itemKeyForUrl(visible[index].bookSourceUrl).currentContext;
      if (context == null) continue;
      final object = context.findRenderObject();
      if (object is! RenderBox || !object.hasSize || !object.attached) {
        continue;
      }
      final rect = object.localToGlobal(Offset.zero) & object.size;
      if (rect.contains(globalPosition)) {
        return index;
      }
    }
    return null;
  }

  void toggleSelection(String url) {
    if (selectedUrls.contains(url)) {
      selectedUrls.remove(url);
    } else {
      selectedUrls.add(url);
    }
  }

  void expandSelectionInterval(List<BookSource> visible) {
    if (selectedUrls.isEmpty || visible.isEmpty) return;
    final selectedIndexes = <int>[];
    for (var index = 0; index < visible.length; index++) {
      if (selectedUrls.contains(visible[index].bookSourceUrl)) {
        selectedIndexes.add(index);
      }
    }
    if (selectedIndexes.isEmpty) return;

    final minIndex = selectedIndexes.reduce(math.min);
    final maxIndex = selectedIndexes.reduce(math.max);
    for (var index = minIndex; index <= maxIndex; index++) {
      selectedUrls.add(visible[index].bookSourceUrl);
    }
  }

  void selectAllOrClearVisible(List<BookSource> visibleSources) {
    final visibleSet =
        visibleSources.map((source) => source.bookSourceUrl).toSet();
    final selectedCount = visibleSources
        .where((source) => selectedUrls.contains(source.bookSourceUrl))
        .length;
    if (visibleSources.isNotEmpty && selectedCount >= visibleSources.length) {
      selectedUrls.removeAll(visibleSet);
      return;
    }
    selectedUrls.addAll(visibleSet);
  }

  void invertVisibleSelection(List<BookSource> visibleSources) {
    for (final source in visibleSources) {
      toggleSelection(source.bookSourceUrl);
    }
  }

  void _applyDragSelectionAt(List<BookSource> visible, int index) {
    if (index < 0 || index >= visible.length) return;
    _dragLastIndex = index;
    final url = visible[index].bookSourceUrl;
    if (_dragSelectValue) {
      selectedUrls.add(url);
      return;
    }
    selectedUrls.remove(url);
  }
}

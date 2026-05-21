// ignore_for_file: invalid_use_of_protected_member

import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:path/path.dart' as p;

import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../import/import_service.dart';
import 'bookshelf_view.dart';

extension BookshelfScanImportDialogs on BookshelfViewState {
  Future<List<String>?> showScanImportSelectionDialog({
    required ImportScanResult scanResult,
  }) async {
    final candidates = List<ImportScanCandidate>.from(scanResult.candidates);
    final selectedPaths =
        candidates.map((candidate) => candidate.filePath).toSet();
    var deletingSelection = false;

    return showCupertinoBottomSheetDialog<List<String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final rootPath = scanResult.rootDirectoryPath;
            final isAllSelected = candidates.isNotEmpty &&
                selectedPaths.length == candidates.length;
            final uiTokens = AppUiTokens.resolve(context);
            return CupertinoAlertDialog(
              title: const Text('智能扫描'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Text('已扫描到 ${candidates.length} 个可导入文件'),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: math
                          .min(320, math.max(180, candidates.length * 56))
                          .toDouble(),
                      child: ListView.builder(
                        itemCount: candidates.length,
                        itemBuilder: (context, index) {
                          final candidate = candidates[index];
                          final isSelected =
                              selectedPaths.contains(candidate.filePath);
                          final relativePath =
                              formatScanCandidatePath(candidate, rootPath);
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onLongPress: deletingSelection
                                ? null
                                : () async {
                                    final shouldDelete =
                                        await showScanCandidateLongPressMenu(
                                      context: context,
                                    );
                                    if (!context.mounted || !shouldDelete) {
                                      return;
                                    }
                                    setDialogState(
                                      () => deletingSelection = true,
                                    );
                                    final deleteResult = await importService
                                        .deleteLocalBooksByPaths(
                                      <String>[candidate.filePath],
                                    );
                                    if (!context.mounted) return;
                                    setDialogState(() {
                                      if (deleteResult.deletedCount > 0) {
                                        candidates.removeWhere(
                                          (entry) =>
                                              entry.filePath ==
                                              candidate.filePath,
                                        );
                                        selectedPaths
                                            .remove(candidate.filePath);
                                      }
                                      deletingSelection = false;
                                    });
                                  },
                            child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              minimumSize: uiTokens.sizes.compactTapSquare,
                              onPressed: () {
                                setDialogState(() {
                                  if (isSelected) {
                                    selectedPaths.remove(candidate.filePath);
                                  } else {
                                    selectedPaths.add(candidate.filePath);
                                  }
                                });
                              },
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            candidate.fileName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: isSelected
                                                  ? CupertinoColors.activeBlue
                                                      .resolveFrom(context)
                                                      .resolveFrom(context)
                                                  : CupertinoColors.label
                                                      .resolveFrom(context)
                                                      .resolveFrom(context),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            relativePath,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: CupertinoColors.systemGrey
                                                  .resolveFrom(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      isSelected
                                          ? CupertinoIcons
                                              .check_mark_circled_solid
                                          : CupertinoIcons.circle,
                                      size: 18,
                                      color: isSelected
                                          ? CupertinoColors.activeBlue
                                              .resolveFrom(context)
                                              .resolveFrom(context)
                                          : CupertinoColors.systemGrey
                                              .resolveFrom(context),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                CupertinoDialogAction(
                  onPressed: deletingSelection
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('取消'),
                ),
                CupertinoDialogAction(
                  onPressed: deletingSelection || candidates.isEmpty
                      ? null
                      : () {
                          setDialogState(() {
                            if (isAllSelected) {
                              selectedPaths.clear();
                              return;
                            }
                            selectedPaths
                              ..clear()
                              ..addAll(
                                candidates
                                    .map((candidate) => candidate.filePath)
                                    .toList(growable: false),
                              );
                          });
                        },
                  child: Text(
                    isAllSelected ? '取消全选' : '全选',
                  ),
                ),
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  onPressed: deletingSelection || selectedPaths.isEmpty
                      ? null
                      : () async {
                          final deletingPaths =
                              selectedPaths.toList(growable: false);
                          setDialogState(() => deletingSelection = true);
                          await importService
                              .deleteLocalBooksByPaths(deletingPaths);
                          if (!context.mounted) return;
                          setDialogState(() {
                            final deletingSet = deletingPaths.toSet();
                            candidates.removeWhere(
                              (candidate) =>
                                  deletingSet.contains(candidate.filePath),
                            );
                            selectedPaths.removeWhere(deletingSet.contains);
                            deletingSelection = false;
                          });
                        },
                  child: Text(
                    deletingSelection ? '删除中...' : '删除',
                  ),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: selectedPaths.isEmpty || deletingSelection
                      ? null
                      : () {
                          Navigator.pop(
                            dialogContext,
                            selectedPaths.toList(growable: false),
                          );
                        },
                  child: const Text('导入'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> showScanCandidateLongPressMenu({
    required BuildContext context,
  }) async {
    final result = await showCupertinoBottomSheetDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(sheetContext).pop(true),
            child: const Text('删除'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(false),
          child: const Text('取消'),
        ),
      ),
    );
    return result ?? false;
  }

  String formatScanCandidatePath(
    ImportScanCandidate candidate,
    String? rootPath,
  ) {
    final normalizedRoot = (rootPath ?? '').trim();
    if (normalizedRoot.isEmpty) {
      return candidate.filePath;
    }
    final normalizedCandidate = p.normalize(candidate.filePath);
    if (normalizedCandidate == normalizedRoot) {
      return candidate.fileName;
    }
    if (!p.isWithin(normalizedRoot, normalizedCandidate)) {
      return normalizedCandidate;
    }
    final relative = p.relative(
      normalizedCandidate,
      from: normalizedRoot,
    );
    return relative.isEmpty ? candidate.fileName : relative;
  }
}

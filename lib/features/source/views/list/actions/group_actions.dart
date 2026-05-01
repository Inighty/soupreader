import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import 'package:soupreader/app/widgets/cupertino_bottom_dialog.dart';
import 'package:soupreader/core/database/database_service.dart';
import 'package:soupreader/core/database/repositories/source_repository.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/views/list/source_list_support.dart';

class SourceListGroupActions {
  const SourceListGroupActions({
    required this.context,
    required this.db,
    required this.sourceRepo,
  });

  final BuildContext context;
  final DatabaseService db;
  final SourceRepository sourceRepo;

  Future<void> showGroupManageSheet() async {
    await showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (sheetContext) {
        return CupertinoPopupSurface(
          isSurfacePainted: true,
          child: SizedBox(
            height: math.min(MediaQuery.of(sheetContext).size.height * 0.78, 560),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '分组管理',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(32, 32),
                        onPressed: () async {
                          final name = await askGroupName('添加分组');
                          if (name == null || name.trim().isEmpty) return;
                          await assignGroupToNoGroupSources(name.trim());
                        },
                        child: const Icon(CupertinoIcons.add_circled),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 0.5,
                  color: CupertinoColors.separator.resolveFrom(sheetContext),
                ),
                Expanded(
                  child: StreamBuilder<List<BookSource>>(
                    stream: sourceRepo.watchAllSources(),
                    builder: (context, snapshot) {
                      final all = snapshot.data ?? sourceRepo.getAllSources();
                      final groups = SourceListSupport.buildGroups(
                        SourceListSupport.normalizeSources(all),
                      );
                      if (groups.isEmpty) return const SizedBox.shrink();

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        itemCount: groups.length,
                        separatorBuilder: (_, __) => Container(
                          height: 0.5,
                          color: CupertinoColors.separator.resolveFrom(context),
                        ),
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          return SizedBox(
                            height: 44,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    group,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                CupertinoButton(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  minimumSize: const Size(36, 30),
                                  onPressed: () async {
                                    final renamed = await askGroupName(
                                      '编辑分组',
                                      initialValue: group,
                                    );
                                    if (renamed == null) return;
                                    await renameGroup(group, renamed.trim());
                                  },
                                  child: const Text('编辑'),
                                ),
                                CupertinoButton(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  minimumSize: const Size(36, 30),
                                  onPressed: () async {
                                    await removeGroupEverywhere(group);
                                  },
                                  child: Text(
                                    '删除',
                                    style: TextStyle(
                                      color: CupertinoColors.systemRed.resolveFrom(
                                        context,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<List<BookSource>> loadAllSourcesForMutation() async {
    final rows = await db.driftDb.select(db.driftDb.sourceRecords).get();
    if (rows.isEmpty) return const <BookSource>[];
    final sources = <BookSource>[];
    for (final row in rows) {
      final raw = (row.rawJson ?? '').trim();
      if (raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            sources.add(BookSource.fromJson(decoded));
            continue;
          }
          if (decoded is Map) {
            sources.add(
              BookSource.fromJson(
                decoded.map((key, value) => MapEntry('$key', value)),
              ),
            );
            continue;
          }
        } catch (_) {
          // ignore and fallback to table fields
        }
      }
      sources.add(
        BookSource.fromJson({
          'bookSourceUrl': row.bookSourceUrl,
          'bookSourceName': row.bookSourceName,
          'bookSourceGroup': row.bookSourceGroup,
          'bookSourceType': row.bookSourceType,
          'enabled': row.enabled,
          'enabledExplore': row.enabledExplore,
          'enabledCookieJar': row.enabledCookieJar ?? true,
          'weight': row.weight,
          'customOrder': row.customOrder,
          'respondTime': row.respondTime,
          'header': row.header,
          'loginUrl': row.loginUrl,
          'bookSourceComment': row.bookSourceComment,
          'lastUpdateTime': row.lastUpdateTime,
        }),
      );
    }
    return SourceListSupport.normalizeSources(sources);
  }

  Future<void> assignGroupToNoGroupSources(String group) async {
    final all = await loadAllSourcesForMutation();
    final targets = all
        .where((source) => (source.bookSourceGroup ?? '').trim().isEmpty)
        .toList(growable: false);
    if (targets.isEmpty) return;
    await Future.wait(
      targets.map(
        (source) => sourceRepo.updateSource(
          copySourceWithGroup(source, group),
        ),
      ),
    );
  }

  Future<void> renameGroup(String oldGroup, String newGroup) async {
    final normalized = newGroup.trim();
    final all = await loadAllSourcesForMutation();
    final targets = all.where((source) {
      return SourceListSupport.splitGroups(source.bookSourceGroup)
          .contains(oldGroup);
    }).toList(growable: false);
    if (targets.isEmpty) return;

    await Future.wait(targets.map((source) async {
      final groups = SourceListSupport.splitGroups(source.bookSourceGroup);
      if (!groups.remove(oldGroup)) return;
      if (normalized.isNotEmpty) groups.add(normalized);
      await sourceRepo.updateSource(
        copySourceWithGroup(source, SourceListSupport.joinGroups(groups)),
      );
    }));
  }

  Future<void> removeGroupEverywhere(String group) async {
    final all = await loadAllSourcesForMutation();
    final targets = all.where((source) {
      return SourceListSupport.splitGroups(source.bookSourceGroup)
          .contains(group);
    }).toList(growable: false);
    await Future.wait(targets.map((source) async {
      final groups = SourceListSupport.splitGroups(source.bookSourceGroup);
      groups.remove(group);
      await sourceRepo.updateSource(
        copySourceWithGroup(source, SourceListSupport.joinGroups(groups)),
      );
    }));
  }

  Future<String?> askGroupName(
    String title, {
    String? initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue ?? '');
    final allGroups = SourceListSupport.buildGroups(
      SourceListSupport.normalizeSources(sourceRepo.getAllSources()),
    );
    final value = await showCupertinoBottomSheetDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final query = controller.text.trim().toLowerCase();
          final quickGroups = allGroups
              .where((group) => query.isEmpty || group.toLowerCase().contains(query))
              .take(12)
              .toList(growable: false);
          return CupertinoAlertDialog(
            title: Text(title),
            content: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoTextField(
                    controller: controller,
                    placeholder: '分组名称',
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  if (quickGroups.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        width: double.infinity,
                        height: math.min(quickGroups.length * 34.0, 118),
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: quickGroups.map((group) {
                              return CupertinoButton(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: const Size(0, 26),
                                onPressed: () {
                                  controller.value = TextEditingValue(
                                    text: group,
                                    selection: TextSelection.collapsed(
                                      offset: group.length,
                                    ),
                                  );
                                  setDialogState(() {});
                                },
                                child: Text(
                                  group,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            }).toList(growable: false),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('取消'),
              ),
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(dialogContext, controller.text),
                child: const Text('确定'),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    return value;
  }

  BookSource copySourceWithGroup(BookSource source, String? group) {
    final normalized = (group ?? '').trim();
    return source.copyWith(bookSourceGroup: normalized);
  }
}

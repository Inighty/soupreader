import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/database/repositories/replace_rule_repository.dart';
import '../models/replace_rule.dart';

/// 「分组管理」底部 sheet。把分组列表抽象出来，渲染 + 编辑 / 删除全部
/// 通过回调由主 State 处理（保证 _addGroup* / _renameGroup / _removeGroup
/// 在原 State 里继续生效，不破坏状态）。
Future<void> showReplaceRuleGroupManageSheet({
  required BuildContext context,
  required ReplaceRuleRepository repo,
  required List<String> Function(List<ReplaceRule> rules) buildGroups,
  required Future<String?> Function({required String title, String? initialValue})
      showGroupInputDialog,
  required Future<void> Function(String groupName) addGroupToNoGroupRules,
  required Future<void> Function({
    required String oldGroup,
    required String newGroup,
  }) renameGroup,
  required Future<void> Function(String group) removeGroup,
}) {
  return showCupertinoBottomSheetDialog<void>(
    context: context,
    builder: (sheetContext) => CupertinoPopupSurface(
      isSurfacePainted: true,
      child: SizedBox(
        height:
            math.min(MediaQuery.of(sheetContext).size.height * 0.78, 560),
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
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(32, 32),
                    onPressed: () async {
                      final name = await showGroupInputDialog(title: '添加分组');
                      if (name == null) return;
                      await addGroupToNoGroupRules(name);
                    },
                    child: const Icon(CupertinoIcons.add_circled),
                  ),
                ],
              ),
            ),
            Container(
              height: 0.5,
              color: CupertinoColors.systemGrey4.resolveFrom(context),
            ),
            Expanded(
              child: StreamBuilder<List<ReplaceRule>>(
                stream: repo.watchAllRules(),
                builder: (context, snapshot) {
                  final allRules = List<ReplaceRule>.from(
                    snapshot.data ?? repo.getAllRules(),
                  )..sort((a, b) => a.order.compareTo(b.order));
                  final groups = buildGroups(allRules);
                  if (groups.isEmpty) {
                    return Center(
                      child: Text(
                        '暂无分组',
                        style: TextStyle(
                          color: CupertinoColors.secondaryLabel
                              .resolveFrom(context),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    itemCount: groups.length,
                    separatorBuilder: (_, __) => Container(
                      height: 0.5,
                      color: CupertinoColors.systemGrey4.resolveFrom(context),
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6),
                              minimumSize: const Size(36, 30),
                              onPressed: () async {
                                final renamed = await showGroupInputDialog(
                                  title: '编辑分组',
                                  initialValue: group,
                                );
                                if (renamed == null) return;
                                await renameGroup(
                                    oldGroup: group, newGroup: renamed);
                              },
                              child: const Text('编辑'),
                            ),
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6),
                              minimumSize: const Size(36, 30),
                              onPressed: () => removeGroup(group),
                              child: Text(
                                '删除',
                                style: TextStyle(
                                  color: CupertinoColors.systemRed
                                      .resolveFrom(context),
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
    ),
  );
}

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../models/rss_source.dart';

/// 列表为空时的占位（无数据 / 无匹配两种文案）。
class RssSourceManageEmptyState extends StatelessWidget {
  const RssSourceManageEmptyState({
    super.key,
    required this.noData,
    required this.onAdd,
    required this.onClearQuery,
  });

  final bool noData;
  final VoidCallback onAdd;
  final VoidCallback onClearQuery;

  @override
  Widget build(BuildContext context) {
    final title = noData ? '暂无订阅源' : '没有匹配结果';
    final action = noData ? '新建订阅源' : '清除筛选';
    final message = noData ? '通过导入或新建来添加第一条订阅源' : '请尝试调整筛选关键字';
    return AppEmptyState(
      illustration: const AppEmptyPlanetIllustration(size: 84),
      title: title,
      message: message,
      action: CupertinoButton(
        onPressed: noData ? onAdd : onClearQuery,
        child: Text(action),
      ),
    );
  }
}

/// 主列表（每个源带勾选/启用/编辑/更多 4 块交互）。
class RssSourceManageList extends StatelessWidget {
  const RssSourceManageList({
    super.key,
    required this.sources,
    required this.selectedSourceUrls,
    required this.onToggleSelection,
    required this.onUpdateEnabled,
    required this.onEditSource,
    required this.onShowSourceActions,
  });

  final List<RssSource> sources;
  final Set<String> selectedSourceUrls;
  final ValueChanged<String> onToggleSelection;
  final void Function(RssSource source, bool value) onUpdateEnabled;
  final ValueChanged<RssSource> onEditSource;
  final ValueChanged<RssSource> onShowSourceActions;

  @override
  Widget build(BuildContext context) {
    return AppListView(
      padding: const EdgeInsets.only(top: 4, bottom: 20),
      children: [
        for (var index = 0; index < sources.length; index++) ...[
          Builder(
            builder: (context) {
              final source = sources[index];
              final sourceUrl = source.sourceUrl.trim();
              final selected = selectedSourceUrls.contains(sourceUrl);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: CupertinoListTile.notched(
                    leading: CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(30, 30),
                      onPressed: () => onToggleSelection(sourceUrl),
                      child: Icon(
                        selected
                            ? CupertinoIcons.check_mark_circled_solid
                            : CupertinoIcons.circle,
                        size: 22,
                        color: selected
                            ? CupertinoColors.activeBlue.resolveFrom(context)
                            : CupertinoColors.secondaryLabel
                                .resolveFrom(context),
                      ),
                    ),
                    title: Text(source.getDisplayNameGroup()),
                    additionalInfo: Text(
                      source.sourceUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CupertinoSwitch(
                          value: source.enabled,
                          onChanged: (value) =>
                              onUpdateEnabled(source, value),
                        ),
                        CupertinoButton(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: const Size(36, 36),
                          onPressed: () => onEditSource(source),
                          child: Icon(
                            CupertinoIcons.pencil,
                            size: 18,
                            color: CupertinoColors.secondaryLabel
                                .resolveFrom(context),
                          ),
                        ),
                        CupertinoButton(
                          padding:
                              const EdgeInsets.only(left: 2, right: 2),
                          minimumSize: const Size(36, 36),
                          onPressed: () => onShowSourceActions(source),
                          child: Icon(
                            CupertinoIcons.ellipsis_vertical,
                            size: 18,
                            color: CupertinoColors.secondaryLabel
                                .resolveFrom(context),
                          ),
                        ),
                      ],
                    ),
                    onTap: () => onEditSource(source),
                  ),
                ),
              );
            },
          ),
          if (index < sources.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// 底部「全选 / 反选 / 更多」操作栏。
class RssSourceManageSelectionBar extends StatelessWidget {
  const RssSourceManageSelectionBar({
    super.key,
    required this.selectedCount,
    required this.totalCount,
    required this.onToggleAll,
    required this.onInvert,
    required this.onShowMore,
  });

  final int selectedCount;
  final int totalCount;
  final VoidCallback onToggleAll;
  final VoidCallback onInvert;
  final VoidCallback onShowMore;

  @override
  Widget build(BuildContext context) {
    final allSelected = totalCount > 0 && selectedCount >= totalCount;
    final canOperate = totalCount > 0;
    final color = CupertinoTheme.of(context).primaryColor;
    final disabledColor = CupertinoColors.systemGrey.resolveFrom(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
          border: Border(
            top: BorderSide(
              color: CupertinoColors.systemGrey4.resolveFrom(context),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                minimumSize: const Size(30, 30),
                alignment: Alignment.centerLeft,
                onPressed: canOperate ? onToggleAll : null,
                child: Text(
                  allSelected
                      ? '取消全选（$selectedCount/$totalCount）'
                      : '全选（$selectedCount/$totalCount）',
                  style: TextStyle(
                    fontSize: 13,
                    color: canOperate ? color : disabledColor,
                  ),
                ),
              ),
            ),
            CupertinoButton(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: const Size(30, 30),
              onPressed: canOperate ? onInvert : null,
              child: Text(
                '反选',
                style: TextStyle(
                  fontSize: 13,
                  color: canOperate ? color : disabledColor,
                ),
              ),
            ),
            CupertinoButton(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              minimumSize: const Size(30, 30),
              onPressed: canOperate ? onShowMore : null,
              child: Icon(
                CupertinoIcons.ellipsis_circle,
                size: 19,
                color: canOperate ? color : disabledColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

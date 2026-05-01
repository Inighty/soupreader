import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/providers/source_edit_notifier.dart';
import 'package:soupreader/features/source/views/edit/actions/page_actions.dart';
import 'package:soupreader/features/source/views/edit/actions/debug_actions.dart';
import 'package:soupreader/features/source/views/edit/source_edit_view_types.dart';

class SourceEditRuleMoreSections extends StatelessWidget {
  const SourceEditRuleMoreSections({
    super.key,
    required this.source,
    required this.state,
    required this.notifier,
    required this.actions,
    required this.debugActions,
  });

  final BookSource source;
  final SourceEditState state;
  final SourceEditNotifier notifier;
  final SourceEditViewActions actions;
  final SourceEditDebugActions debugActions;

  @override
  Widget build(BuildContext context) {
    final hasPreviewChapterUrl =
        (state.previewChapterUrl ?? '').trim().isNotEmpty;
    return Column(
      children: [
        _BookInfoSection(
          rule: source.ruleBookInfo ?? const BookInfoRule(),
          onUpdate: (next) => notifier.updateSource(
            (current) => current.copyWith(ruleBookInfo: next),
          ),
        ),
        _TocSection(
          rule: source.ruleToc ?? const TocRule(),
          onUpdate: (next) => notifier.updateSource(
            (current) => current.copyWith(ruleToc: next),
          ),
        ),
        _ContentSection(
          rule: source.ruleContent ?? const ContentRule(),
          onUpdate: (next) => notifier.updateSource(
            (current) => current.copyWith(ruleContent: next),
          ),
        ),
        CupertinoListSection.insetGrouped(
          header: const Text('字段即时预览（基于最近一次调试）'),
          children: [
            CupertinoListTile.notched(
              title: const Text('chapterName 预览'),
              additionalInfo: Text(
                (state.previewChapterName ?? '').isEmpty ? '—' : '已提取',
              ),
              trailing: const CupertinoListTileChevron(),
              onTap: (state.previewChapterName ?? '').isEmpty
                  ? null
                  : () => actions.openDebugText(
                        title: 'chapterName 预览',
                        text: state.previewChapterName!,
                      ),
            ),
            CupertinoListTile.notched(
              title: const Text('chapterUrl 预览'),
              additionalInfo: Text(
                (state.previewChapterUrl ?? '').isEmpty ? '—' : '已提取',
              ),
              trailing: const CupertinoListTileChevron(),
              onTap: (state.previewChapterUrl ?? '').isEmpty
                  ? null
                  : () => actions.openDebugText(
                        title: 'chapterUrl 预览',
                        text: state.previewChapterUrl!,
                      ),
            ),
            CupertinoListTile.notched(
              title: const Text('content 预览'),
              additionalInfo: Text(
                (state.debugContentResult ?? '').trim().isEmpty
                    ? '—'
                    : '${state.debugContentResult!.length} 字符',
              ),
              trailing: const CupertinoListTileChevron(),
              onTap: (state.debugContentResult ?? '').trim().isEmpty
                  ? null
                  : () => actions.openDebugText(
                        title: 'content 预览',
                        text: state.debugContentResult!,
                      ),
            ),
          ],
        ),
        CupertinoListSection.insetGrouped(
          header: const Text('规则页快速测试'),
          footer: const Text('会自动切到调试页并执行，便于边改规则边验证。'),
          children: [
            CupertinoListTile.notched(
              title: const Text('测试搜索规则'),
              subtitle: const Text('使用 checkKeyWord；为空时回退“我的”'),
              trailing: const CupertinoListTileChevron(),
              onTap: () => debugActions.runQuickSearchRuleTest(),
            ),
            CupertinoListTile.notched(
              title: const Text('测试正文规则'),
              subtitle: Text(
                hasPreviewChapterUrl
                    ? '使用最近章节链接（--contentUrl）'
                    : '需先在调试中拿到 chapterUrl 后再测正文',
              ),
              trailing: const CupertinoListTileChevron(),
              onTap: () => debugActions.runQuickContentRuleTest(),
            ),
          ],
        ),
        CupertinoListSection.insetGrouped(
          children: [
            CupertinoListTile.notched(
              title: const Text('规则体检（Lint）'),
              subtitle: const Text('检查关键字段缺失、规则格式风险与链路可用性风险'),
              trailing: const CupertinoListTileChevron(),
              onTap: () => actions.runRuleLint(),
            ),
            CupertinoListTile.notched(
              title: const Text('同步到 JSON'),
              subtitle: const Text('当前字段修改已实时同步，这里直接切到 JSON 页'),
              trailing: const CupertinoListTileChevron(),
              onTap: actions.syncToJsonTab,
            ),
            CupertinoListTile.notched(
              title: const Text('从 JSON 解析'),
              subtitle: const Text('按当前 JSON 内容刷新字段状态'),
              trailing: const CupertinoListTileChevron(),
              onTap: actions.syncFromJson,
            ),
          ],
        ),
      ],
    );
  }
}

class _BookInfoSection extends StatelessWidget {
  const _BookInfoSection({
    required this.rule,
    required this.onUpdate,
  });

  final BookInfoRule rule;
  final ValueChanged<BookInfoRule> onUpdate;

  @override
  Widget build(BuildContext context) {
    return CupertinoListSection.insetGrouped(
      header: const Text('详情规则（ruleBookInfo）'),
      children: [
        SourceEditValueFieldTile(
          title: '根节点',
          value: rule.init ?? '',
          onChanged: (value) =>
              onUpdate(rule.copyWith(init: value.isEmpty ? null : value)),
          placeholder: 'ruleBookInfo.init（可选）',
        ),
        SourceEditValueFieldTile(
          title: '书名',
          value: rule.name ?? '',
          onChanged: (value) =>
              onUpdate(rule.copyWith(name: value.isEmpty ? null : value)),
          placeholder: 'ruleBookInfo.name',
        ),
        SourceEditValueFieldTile(
          title: '作者',
          value: rule.author ?? '',
          onChanged: (value) =>
              onUpdate(rule.copyWith(author: value.isEmpty ? null : value)),
          placeholder: 'ruleBookInfo.author',
        ),
        SourceEditValueFieldTile(
          title: '封面',
          value: rule.coverUrl ?? '',
          onChanged: (value) =>
              onUpdate(rule.copyWith(coverUrl: value.isEmpty ? null : value)),
          placeholder: 'ruleBookInfo.coverUrl',
        ),
        SourceEditValueFieldTile(
          title: '简介',
          value: rule.intro ?? '',
          onChanged: (value) =>
              onUpdate(rule.copyWith(intro: value.isEmpty ? null : value)),
          placeholder: 'ruleBookInfo.intro',
          maxLines: 3,
        ),
        SourceEditValueFieldTile(
          title: '分类/类型',
          value: rule.kind ?? '',
          onChanged: (value) =>
              onUpdate(rule.copyWith(kind: value.isEmpty ? null : value)),
          placeholder: 'ruleBookInfo.kind（可选）',
        ),
        SourceEditValueFieldTile(
          title: '最新章节',
          value: rule.lastChapter ?? '',
          onChanged: (value) => onUpdate(
            rule.copyWith(lastChapter: value.isEmpty ? null : value),
          ),
          placeholder: 'ruleBookInfo.lastChapter',
        ),
        SourceEditValueFieldTile(
          title: '更新时间',
          value: rule.updateTime ?? '',
          onChanged: (value) => onUpdate(
            rule.copyWith(updateTime: value.isEmpty ? null : value),
          ),
          placeholder: 'ruleBookInfo.updateTime（可选）',
        ),
        SourceEditValueFieldTile(
          title: '字数',
          value: rule.wordCount ?? '',
          onChanged: (value) => onUpdate(
            rule.copyWith(wordCount: value.isEmpty ? null : value),
          ),
          placeholder: 'ruleBookInfo.wordCount（可选）',
        ),
        SourceEditValueFieldTile(
          title: '目录链接',
          value: rule.tocUrl ?? '',
          onChanged: (value) =>
              onUpdate(rule.copyWith(tocUrl: value.isEmpty ? null : value)),
          placeholder: 'ruleBookInfo.tocUrl（@href）',
        ),
      ],
    );
  }
}

class _TocSection extends StatelessWidget {
  const _TocSection({
    required this.rule,
    required this.onUpdate,
  });

  final TocRule rule;
  final ValueChanged<TocRule> onUpdate;

  @override
  Widget build(BuildContext context) {
    return CupertinoListSection.insetGrouped(
      header: const Text('目录规则（ruleToc）'),
      children: [
        SourceEditValueFieldTile(
          title: '章节列表',
          value: rule.chapterList ?? '',
          onChanged: (value) => onUpdate(
            rule.copyWith(chapterList: value.isEmpty ? null : value),
          ),
          placeholder: 'ruleToc.chapterList',
        ),
        SourceEditValueFieldTile(
          title: '章节名',
          value: rule.chapterName ?? '',
          onChanged: (value) => onUpdate(
            rule.copyWith(chapterName: value.isEmpty ? null : value),
          ),
          placeholder: 'ruleToc.chapterName',
        ),
        SourceEditValueFieldTile(
          title: '章节链接',
          value: rule.chapterUrl ?? '',
          onChanged: (value) => onUpdate(
            rule.copyWith(chapterUrl: value.isEmpty ? null : value),
          ),
          placeholder: 'ruleToc.chapterUrl（@href）',
        ),
        SourceEditValueFieldTile(
          title: '目录下一页',
          value: rule.nextTocUrl ?? '',
          onChanged: (value) => onUpdate(
            rule.copyWith(nextTocUrl: value.isEmpty ? null : value),
          ),
          placeholder: 'ruleToc.nextTocUrl（可选，支持多候选）',
        ),
        SourceEditValueFieldTile(
          title: '目录预处理JS',
          value: rule.preUpdateJs ?? '',
          onChanged: (value) => onUpdate(
            rule.copyWith(preUpdateJs: value.isEmpty ? null : value),
          ),
          placeholder: 'ruleToc.preUpdateJs（可选，JS）',
          maxLines: 4,
        ),
        SourceEditValueFieldTile(
          title: '标题格式化JS',
          value: rule.formatJs ?? '',
          onChanged: (value) => onUpdate(
            rule.copyWith(formatJs: value.isEmpty ? null : value),
          ),
          placeholder: 'ruleToc.formatJs（可选，JS）',
          maxLines: 4,
        ),
      ],
    );
  }
}

class _ContentSection extends StatelessWidget {
  const _ContentSection({
    required this.rule,
    required this.onUpdate,
  });

  final ContentRule rule;
  final ValueChanged<ContentRule> onUpdate;

  @override
  Widget build(BuildContext context) {
    return CupertinoListSection.insetGrouped(
      header: const Text('正文规则（ruleContent）'),
      children: [
        SourceEditValueFieldTile(
          title: '标题（可选）',
          value: rule.title ?? '',
          onChanged: (value) =>
              onUpdate(rule.copyWith(title: value.isEmpty ? null : value)),
          placeholder: 'ruleContent.title',
        ),
        SourceEditValueFieldTile(
          title: '正文',
          value: rule.content ?? '',
          onChanged: (value) =>
              onUpdate(rule.copyWith(content: value.isEmpty ? null : value)),
          placeholder: 'ruleContent.content（@text/@html）',
          maxLines: 4,
        ),
        SourceEditValueFieldTile(
          title: '正文下一页',
          value: rule.nextContentUrl ?? '',
          onChanged: (value) => onUpdate(
            rule.copyWith(nextContentUrl: value.isEmpty ? null : value),
          ),
          placeholder: 'ruleContent.nextContentUrl（可选，支持多候选）',
        ),
        SourceEditValueFieldTile(
          title: '替换正则',
          value: rule.replaceRegex ?? '',
          onChanged: (value) => onUpdate(
            rule.copyWith(replaceRegex: value.isEmpty ? null : value),
          ),
          placeholder: 'ruleContent.replaceRegex（regex##rep##...）',
          maxLines: 4,
        ),
      ],
    );
  }
}

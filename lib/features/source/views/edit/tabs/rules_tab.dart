import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/providers/source_edit_notifier.dart';
import 'package:soupreader/features/source/views/edit/actions/page_actions.dart';
import 'package:soupreader/features/source/views/edit/actions/debug_actions.dart';
import 'package:soupreader/features/source/views/edit/tabs/rules_more.dart';
import 'package:soupreader/features/source/views/edit/source_edit_view_types.dart';

class SourceEditRulesTab extends ConsumerWidget {
  const SourceEditRulesTab({
    super.key,
    required this.args,
    required this.actions,
    required this.debugActions,
  });

  final SourceEditArgs args;
  final SourceEditViewActions actions;
  final SourceEditDebugActions debugActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sourceEditProvider(args));
    final notifier = ref.read(sourceEditProvider(args).notifier);
    final source = state.source;

    return ListView(
      children: [
        _RuleSearchSection(
          rule: source.ruleSearch ?? const SearchRule(),
          onUpdate: (next) => notifier.updateSource(
            (current) => current.copyWith(ruleSearch: next),
          ),
        ),
        _RuleExploreSection(
          rule: source.ruleExplore ?? const ExploreRule(),
          onUpdate: (next) => notifier.updateSource(
            (current) => current.copyWith(ruleExplore: next),
          ),
        ),
        SourceEditRuleMoreSections(
          source: source,
          state: state,
          notifier: notifier,
          actions: actions,
          debugActions: debugActions,
        ),
      ],
    );
  }
}

class _RuleSearchSection extends StatelessWidget {
  const _RuleSearchSection({
    required this.rule,
    required this.onUpdate,
  });

  final SearchRule rule;
  final ValueChanged<SearchRule> onUpdate;

  @override
  Widget build(BuildContext context) {
    return CupertinoListSection.insetGrouped(
      header: const Text('搜索规则（ruleSearch）'),
      footer: const Text(
        '常用规则为 CSS 选择器，可用 “selector@href/@src/@text/@html” 等形式取值。',
      ),
      children: [
        SourceEditValueFieldTile(
          title: '校验关键词',
          value: rule.checkKeyWord ?? '',
          onChanged: (value) => onUpdate(
            rule.copyWith(checkKeyWord: value.isEmpty ? null : value),
          ),
          placeholder: 'ruleSearch.checkKeyWord（用于可用性检测）',
        ),
        SourceEditValueFieldTile(
          title: '书籍列表',
          value: rule.bookList ?? '',
          onChanged: (value) => onUpdate(
            rule.copyWith(bookList: value.isEmpty ? null : value),
          ),
          placeholder: 'ruleSearch.bookList（CSS 选择器）',
        ),
        SourceEditValueFieldTile(
          title: '书名',
          value: rule.name ?? '',
          onChanged: (value) => onUpdate(
            rule.copyWith(name: value.isEmpty ? null : value),
          ),
          placeholder: 'ruleSearch.name',
        ),
        SourceEditValueFieldTile(
          title: '作者',
          value: rule.author ?? '',
          onChanged: (value) => onUpdate(
            rule.copyWith(author: value.isEmpty ? null : value),
          ),
          placeholder: 'ruleSearch.author',
        ),
        SourceEditValueFieldTile(
          title: '分类/类型',
          value: rule.kind ?? '',
          onChanged: (value) => onUpdate(
            rule.copyWith(kind: value.isEmpty ? null : value),
          ),
          placeholder: 'ruleSearch.kind（可选）',
        ),
        SourceEditValueFieldTile(
          title: '封面',
          value: rule.coverUrl ?? '',
          onChanged: (value) => onUpdate(
            rule.copyWith(coverUrl: value.isEmpty ? null : value),
          ),
          placeholder: 'ruleSearch.coverUrl（@src）',
        ),
        SourceEditValueFieldTile(
          title: '简介',
          value: rule.intro ?? '',
          onChanged: (value) => onUpdate(
            rule.copyWith(intro: value.isEmpty ? null : value),
          ),
          placeholder: 'ruleSearch.intro',
        ),
        SourceEditValueFieldTile(
          title: '最新章节',
          value: rule.lastChapter ?? '',
          onChanged: (value) => onUpdate(
            rule.copyWith(lastChapter: value.isEmpty ? null : value),
          ),
          placeholder: 'ruleSearch.lastChapter',
        ),
        SourceEditValueFieldTile(
          title: '更新时间',
          value: rule.updateTime ?? '',
          onChanged: (value) => onUpdate(
            rule.copyWith(updateTime: value.isEmpty ? null : value),
          ),
          placeholder: 'ruleSearch.updateTime（可选）',
        ),
        SourceEditValueFieldTile(
          title: '字数',
          value: rule.wordCount ?? '',
          onChanged: (value) => onUpdate(
            rule.copyWith(wordCount: value.isEmpty ? null : value),
          ),
          placeholder: 'ruleSearch.wordCount（可选）',
        ),
        SourceEditValueFieldTile(
          title: '详情链接',
          value: rule.bookUrl ?? '',
          onChanged: (value) => onUpdate(
            rule.copyWith(bookUrl: value.isEmpty ? null : value),
          ),
          placeholder: 'ruleSearch.bookUrl（@href）',
        ),
      ],
    );
  }
}

class _RuleExploreSection extends StatelessWidget {
  const _RuleExploreSection({
    required this.rule,
    required this.onUpdate,
  });

  final ExploreRule rule;
  final ValueChanged<ExploreRule> onUpdate;

  @override
  Widget build(BuildContext context) {
    return CupertinoListSection.insetGrouped(
      header: const Text('发现规则（ruleExplore）'),
      children: [
        SourceEditValueFieldTile(
          title: '书籍列表',
          value: rule.bookList ?? '',
          onChanged: (value) => onUpdate(
            rule.copyWith(bookList: value.isEmpty ? null : value),
          ),
          placeholder: 'ruleExplore.bookList',
        ),
        SourceEditValueFieldTile(
          title: '书名',
          value: rule.name ?? '',
          onChanged: (value) => onUpdate(
            rule.copyWith(name: value.isEmpty ? null : value),
          ),
          placeholder: 'ruleExplore.name',
        ),
        SourceEditValueFieldTile(
          title: '作者',
          value: rule.author ?? '',
          onChanged: (value) => onUpdate(
            rule.copyWith(author: value.isEmpty ? null : value),
          ),
          placeholder: 'ruleExplore.author',
        ),
        SourceEditValueFieldTile(
          title: '分类/类型',
          value: rule.kind ?? '',
          onChanged: (value) => onUpdate(
            rule.copyWith(kind: value.isEmpty ? null : value),
          ),
          placeholder: 'ruleExplore.kind（可选）',
        ),
        SourceEditValueFieldTile(
          title: '封面',
          value: rule.coverUrl ?? '',
          onChanged: (value) => onUpdate(
            rule.copyWith(coverUrl: value.isEmpty ? null : value),
          ),
          placeholder: 'ruleExplore.coverUrl',
        ),
        SourceEditValueFieldTile(
          title: '简介',
          value: rule.intro ?? '',
          onChanged: (value) => onUpdate(
            rule.copyWith(intro: value.isEmpty ? null : value),
          ),
          placeholder: 'ruleExplore.intro',
        ),
        SourceEditValueFieldTile(
          title: '最新章节',
          value: rule.lastChapter ?? '',
          onChanged: (value) => onUpdate(
            rule.copyWith(lastChapter: value.isEmpty ? null : value),
          ),
          placeholder: 'ruleExplore.lastChapter',
        ),
        SourceEditValueFieldTile(
          title: '更新时间',
          value: rule.updateTime ?? '',
          onChanged: (value) => onUpdate(
            rule.copyWith(updateTime: value.isEmpty ? null : value),
          ),
          placeholder: 'ruleExplore.updateTime（可选）',
        ),
        SourceEditValueFieldTile(
          title: '字数',
          value: rule.wordCount ?? '',
          onChanged: (value) => onUpdate(
            rule.copyWith(wordCount: value.isEmpty ? null : value),
          ),
          placeholder: 'ruleExplore.wordCount（可选）',
        ),
        SourceEditValueFieldTile(
          title: '详情链接',
          value: rule.bookUrl ?? '',
          onChanged: (value) => onUpdate(
            rule.copyWith(bookUrl: value.isEmpty ? null : value),
          ),
          placeholder: 'ruleExplore.bookUrl',
        ),
      ],
    );
  }
}

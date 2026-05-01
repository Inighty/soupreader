import 'package:flutter/cupertino.dart';

import 'package:soupreader/features/source/providers/source_edit_notifier.dart';
import 'package:soupreader/features/source/views/edit/actions/debug_actions.dart';

class SourceEditDebugQuickActionsSection extends StatelessWidget {
  const SourceEditDebugQuickActionsSection({
    super.key,
    required this.state,
    required this.debugActions,
  });

  final SourceEditState state;
  final SourceEditDebugActions debugActions;

  @override
  Widget build(BuildContext context) {
    final searchKey = state.source.ruleSearch?.checkKeyWord?.trim() ?? '';
    final defaultSearchKey = searchKey.isEmpty ? '我的' : searchKey;
    final exploreEntries = debugActions.collectExploreQuickEntries();

    final actions = <Widget>[
      _DebugQuickButton(
        label: defaultSearchKey,
        onTap: () async {
          debugActions.setDebugKey(defaultSearchKey);
          await debugActions.startDebug();
        },
      ),
      _DebugQuickButton(
        label: '系统',
        onTap: () async {
          debugActions.setDebugKey('系统');
          await debugActions.startDebug();
        },
      ),
      if (exploreEntries.isNotEmpty)
        _DebugQuickButton(
          label: exploreEntries.first.value,
          onTap: () async {
            debugActions.setDebugKey(exploreEntries.first.key);
            await debugActions.startDebug();
          },
        ),
      if (exploreEntries.length > 1)
        _DebugQuickButton(
          label: '发现候选',
          onTap: () => debugActions.showExploreQuickPicker(),
        ),
      _DebugQuickButton(
        label: '详情URL',
        onTap: () => debugActions.runCurrentKey(),
      ),
      _DebugQuickButton(
        label: '++目录',
        onTap: () => debugActions.prefixKeyAndRun('++'),
      ),
      _DebugQuickButton(
        label: '--正文',
        onTap: () => debugActions.prefixKeyAndRun('--'),
      ),
    ];

    return CupertinoListSection.insetGrouped(
      header: const Text('快捷'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '搜索关键字：我的 / 系统；发现：标题::url；目录：++url；正文：--url',
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: actions,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DebugQuickButton extends StatelessWidget {
  const _DebugQuickButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey5.resolveFrom(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: const Size(0, 0),
        onPressed: onTap,
        child: Text(
          label,
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }
}

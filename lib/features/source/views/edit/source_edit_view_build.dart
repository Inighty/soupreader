import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:soupreader/app/theme/ui_tokens.dart';
import 'package:soupreader/features/source/providers/source_edit_notifier.dart';

class SourceEditTopControlBar extends ConsumerWidget {
  const SourceEditTopControlBar({
    super.key,
    required this.args,
    required this.onPickSourceType,
  });

  final SourceEditArgs args;
  final Future<void> Function() onPickSourceType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sourceEditProvider(args));
    final notifier = ref.read(sourceEditProvider(args).notifier);
    final source = state.source;
    final ui = AppUiTokens.resolve(context);
    final baseStyle = CupertinoTheme.of(context).textTheme.textStyle;
    final labelStyle = baseStyle.copyWith(
      fontSize: 14,
      letterSpacing: -0.2,
    );
    final typeBg = CupertinoColors.tertiarySystemFill.resolveFrom(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Text(
            '书源类型',
            style: labelStyle.copyWith(color: ui.colors.secondaryLabel),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onPickSourceType,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: typeBg,
                borderRadius: BorderRadius.circular(ui.radii.control),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _sourceTypeLabel(source.bookSourceType),
                      style: labelStyle,
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      CupertinoIcons.chevron_down,
                      size: 11,
                      color: ui.colors.tertiaryLabel,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          _TopSwitch(
            label: '启用',
            value: source.enabled,
            onChanged: (value) => notifier.updateSource(
              (current) => current.copyWith(enabled: value),
            ),
          ),
          const SizedBox(width: 12),
          _TopSwitch(
            label: '发现',
            value: source.enabledExplore,
            onChanged: (value) => notifier.updateSource(
              (current) => current.copyWith(enabledExplore: value),
            ),
          ),
          const SizedBox(width: 12),
          _TopSwitch(
            label: 'Cookie',
            value: source.enabledCookieJar,
            onChanged: (value) => notifier.updateSource(
              (current) => current.copyWith(enabledCookieJar: value),
            ),
          ),
        ],
      ),
    );
  }
}

class SourceEditTabControl extends StatelessWidget {
  const SourceEditTabControl({
    super.key,
    required this.tabIndex,
    required this.onChanged,
  });

  final int tabIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final style = CupertinoTheme.of(context).textTheme.textStyle.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.2,
        );

    Widget segment(String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: style,
          ),
        );

    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<int>(
        groupValue: tabIndex,
        padding: const EdgeInsets.all(3),
        children: {
          0: segment('基础'),
          1: segment('规则'),
          2: segment('JSON'),
          3: segment('调试'),
        },
        onValueChanged: (value) {
          if (value == null) return;
          onChanged(value);
        },
      ),
    );
  }
}

class _TopSwitch extends StatelessWidget {
  const _TopSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ui = AppUiTokens.resolve(context);
    final labelStyle = CupertinoTheme.of(context).textTheme.textStyle.copyWith(
          fontSize: 14,
          letterSpacing: -0.2,
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: labelStyle.copyWith(color: ui.colors.secondaryLabel),
        ),
        const SizedBox(width: 5),
        Transform.scale(
          scale: 0.78,
          child: CupertinoSwitch(
            value: value,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

const _sourceTypes = [
  (value: 0, label: '文本'),
  (value: 1, label: '音频'),
  (value: 2, label: '图片'),
  (value: 3, label: '文件'),
];

String _sourceTypeLabel(int type) {
  for (final item in _sourceTypes) {
    if (item.value == type) return item.label;
  }
  return '文本';
}

import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import 'package:soupreader/app/widgets/app_ui_kit.dart';
import 'package:soupreader/features/source/views/list/source_list_types.dart';

class SourceSortSheet extends StatefulWidget {
  static const double _radius = 18;
  static const double _handleWidth = 36;
  static const double _handleHeight = 4;
  static const List<SourceSortMode> _modeOrder = [
    SourceSortMode.name,
    SourceSortMode.url,
    SourceSortMode.update,
    SourceSortMode.weight,
    SourceSortMode.respond,
    SourceSortMode.enabled,
    SourceSortMode.manual,
  ];

  final SourceSortMode mode;
  final bool ascending;
  final SourceSortModeLabelBuilder modeLabelBuilder;
  final SourceSortChanged onChanged;

  const SourceSortSheet({
    super.key,
    required this.mode,
    required this.ascending,
    required this.modeLabelBuilder,
    required this.onChanged,
  });

  @override
  State<SourceSortSheet> createState() => _SourceSortSheetState();
}

class _SourceSortSheetState extends State<SourceSortSheet> {
  late SourceSortMode _mode;
  late bool _ascending;

  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
    _ascending = widget.ascending;
  }

  void _update({
    SourceSortMode? mode,
    bool? ascending,
  }) {
    setState(() {
      if (mode != null) _mode = mode;
      if (ascending != null) _ascending = ascending;
    });
    widget.onChanged(_mode, _ascending);
  }

  @override
  Widget build(BuildContext context) {
    final sheetBg =
        CupertinoColors.systemGroupedBackground.resolveFrom(context);
    final titleColor = CupertinoColors.label.resolveFrom(context);
    final handleColor = CupertinoColors.separator.resolveFrom(context);
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = math.max(mediaQuery.padding.bottom, 8.0);

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(SourceSortSheet._radius),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(0, 10, 0, bottomInset),
          child: ListView(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            children: [
              _buildHeader(handleColor: handleColor, titleColor: titleColor),
              AppListSection(
                header: const Text('类型'),
                hasLeading: false,
                children: [
                  for (final mode in SourceSortSheet._modeOrder)
                    _buildOptionRow(
                      title: widget.modeLabelBuilder(mode),
                      selected: _mode == mode,
                      onTap: () => _update(mode: mode),
                    ),
                ],
              ),
              AppListSection(
                header: const Text('顺序'),
                hasLeading: false,
                children: [
                  _buildOptionRow(
                    title: '升序',
                    selected: _ascending,
                    onTap: () => _update(ascending: true),
                  ),
                  _buildOptionRow(
                    title: '降序',
                    selected: !_ascending,
                    onTap: () => _update(ascending: false),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({
    required Color handleColor,
    required Color titleColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: SourceSortSheet._handleWidth,
          height: SourceSortSheet._handleHeight,
          decoration: BoxDecoration(
            color: handleColor,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Text(
            '排序',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: titleColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionRow({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final accent = CupertinoTheme.of(context).primaryColor;
    return AppListTile(
      title: Text(
        title,
        style: TextStyle(
          color: selected ? accent : CupertinoColors.label.resolveFrom(context),
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
      trailing: selected
          ? Icon(CupertinoIcons.check_mark, size: 18, color: accent)
          : null,
      onTap: onTap,
      showChevron: false,
    );
  }
}

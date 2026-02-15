import 'package:flutter/cupertino.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../source/models/book_source.dart';

class SearchScopePickerView extends StatefulWidget {
  final List<BookSource> sources;
  final Set<String> initialSelectedUrls;

  const SearchScopePickerView({
    super.key,
    required this.sources,
    required this.initialSelectedUrls,
  });

  @override
  State<SearchScopePickerView> createState() => _SearchScopePickerViewState();
}

class _SearchScopePickerViewState extends State<SearchScopePickerView> {
  final TextEditingController _queryController = TextEditingController();
  late final List<BookSource> _sources;
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _sources = widget.sources.toList(growable: false)
      ..sort((a, b) {
        if (a.customOrder != b.customOrder) {
          return a.customOrder.compareTo(b.customOrder);
        }
        if (a.weight != b.weight) {
          return b.weight.compareTo(a.weight);
        }
        return a.bookSourceName.compareTo(b.bookSourceName);
      });
    _selected = widget.initialSelectedUrls
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  List<BookSource> get _filteredSources {
    final query = _queryController.text.trim().toLowerCase();
    if (query.isEmpty) return _sources;
    return _sources.where((source) {
      final name = source.bookSourceName.toLowerCase();
      final url = source.bookSourceUrl.toLowerCase();
      final group = (source.bookSourceGroup ?? '').toLowerCase();
      return name.contains(query) ||
          url.contains(query) ||
          group.contains(query);
    }).toList(growable: false);
  }

  void _toggle(String sourceUrl) {
    setState(() {
      if (_selected.contains(sourceUrl)) {
        _selected.remove(sourceUrl);
      } else {
        _selected.add(sourceUrl);
      }
    });
  }

  void _submit() {
    final selected = _selected.toList(growable: false)..sort();
    Navigator.of(context).pop(selected);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSources;
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;

    return AppCupertinoPageScaffold(
      title: '搜索范围',
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(30, 30),
        onPressed: _submit,
        child: const Text('完成'),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: ShadInput(
              controller: _queryController,
              placeholder: const Text('查找书源'),
              leading: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(LucideIcons.search, size: 16),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Text(
                  '已选 ${_selected.length}/${_sources.length}',
                  style: theme.textTheme.small.copyWith(
                    color: scheme.mutedForeground,
                  ),
                ),
                const Spacer(),
                ShadButton.link(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => setState(() => _selected.clear()),
                  child: const Text('取消全选'),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      '未找到匹配书源',
                      style: theme.textTheme.muted.copyWith(
                        color: scheme.mutedForeground,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final source = filtered[index];
                      final selected = _selected.contains(source.bookSourceUrl);
                      return GestureDetector(
                        key: ValueKey(source.bookSourceUrl),
                        onTap: () => _toggle(source.bookSourceUrl),
                        child: ShadCard(
                          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      source.bookSourceName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.p.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      source.bookSourceUrl,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.small.copyWith(
                                        color: scheme.mutedForeground,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Icon(
                                selected
                                    ? CupertinoIcons.check_mark_circled_solid
                                    : CupertinoIcons.circle,
                                size: 20,
                                color: selected
                                    ? scheme.primary
                                    : scheme.mutedForeground,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

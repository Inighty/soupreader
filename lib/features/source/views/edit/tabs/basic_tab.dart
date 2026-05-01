import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:soupreader/features/source/providers/source_edit_notifier.dart';
import 'package:soupreader/features/source/views/edit/actions/page_actions.dart';
import 'package:soupreader/features/source/views/edit/source_edit_view_types.dart';

class SourceEditBasicTab extends ConsumerWidget {
  const SourceEditBasicTab({
    super.key,
    required this.args,
    required this.actions,
  });

  final SourceEditArgs args;
  final SourceEditViewActions actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sourceEditProvider(args));
    final notifier = ref.read(sourceEditProvider(args).notifier);
    final source = state.source;

    return ListView(
      children: [
        CupertinoListSection.insetGrouped(
          header: const Text('基础信息'),
          children: [
            SourceEditValueFieldTile(
              title: '名称',
              value: source.bookSourceName,
              onChanged: (value) => notifier.updateSource(
                (current) => current.copyWith(bookSourceName: value),
              ),
              placeholder: 'bookSourceName',
            ),
            SourceEditValueFieldTile(
              title: '地址',
              value: source.bookSourceUrl,
              onChanged: (value) => notifier.updateSource(
                (current) => current.copyWith(bookSourceUrl: value),
              ),
              placeholder: 'bookSourceUrl',
            ),
            SourceEditValueFieldTile(
              title: '分组',
              value: source.bookSourceGroup ?? '',
              onChanged: (value) => notifier.updateSource(
                (current) => current.copyWith(
                  bookSourceGroup: value.isEmpty ? null : value,
                ),
              ),
              placeholder: 'bookSourceGroup',
            ),
            CupertinoListTile.notched(
              title: const Text('类型'),
              additionalInfo: Text(_sourceTypeLabel(source.bookSourceType)),
              trailing: const CupertinoListTileChevron(),
              onTap: () => actions.pickSourceType(),
            ),
            SourceEditValueFieldTile(
              title: '自定义排序',
              value: source.customOrder.toString(),
              onChanged: (value) => notifier.updateSource(
                (current) => current.copyWith(
                  customOrder: int.tryParse(value.trim()) ?? 0,
                ),
              ),
              placeholder: 'customOrder（数字）',
            ),
            SourceEditValueFieldTile(
              title: '权重',
              value: source.weight.toString(),
              onChanged: (value) => notifier.updateSource(
                (current) => current.copyWith(
                  weight: int.tryParse(value.trim()) ?? 0,
                ),
              ),
              placeholder: 'weight（数字）',
            ),
          ],
        ),
        CupertinoListSection.insetGrouped(
          header: const Text('网络/登录'),
          children: [
            SourceEditValueFieldTile(
              title: '请求超时',
              value: source.respondTime.toString(),
              onChanged: (value) => notifier.updateSource(
                (current) => current.copyWith(
                  respondTime: int.tryParse(value.trim()) ?? 180000,
                ),
              ),
              placeholder: 'respondTime（毫秒）',
            ),
            SourceEditValueFieldTile(
              title: '并发速率',
              value: source.concurrentRate ?? '',
              onChanged: (value) => notifier.updateSource(
                (current) => current.copyWith(
                  concurrentRate: value.isEmpty ? null : value,
                ),
              ),
              placeholder: 'concurrentRate（可空）',
            ),
            SourceEditValueFieldTile(
              title: 'Header',
              value: source.header ?? '',
              onChanged: (value) => notifier.updateSource(
                (current) => current.copyWith(
                  header: value.isEmpty ? null : value,
                ),
              ),
              placeholder: 'header（支持 JSON 或每行 key:value）',
              maxLines: 6,
            ),
            SourceEditValueFieldTile(
              title: '登录地址',
              value: source.loginUrl ?? '',
              onChanged: (value) => notifier.updateSource(
                (current) => current.copyWith(
                  loginUrl: value.isEmpty ? null : value,
                ),
              ),
              placeholder: 'loginUrl',
            ),
            SourceEditValueFieldTile(
              title: '登录 UI',
              value: source.loginUi ?? '',
              onChanged: (value) => notifier.updateSource(
                (current) => current.copyWith(
                  loginUi: value.isEmpty ? null : value,
                ),
              ),
              placeholder: 'loginUi（可空）',
              maxLines: 3,
            ),
            SourceEditValueFieldTile(
              title: '登录检查 JS',
              value: source.loginCheckJs ?? '',
              onChanged: (value) => notifier.updateSource(
                (current) => current.copyWith(
                  loginCheckJs: value.isEmpty ? null : value,
                ),
              ),
              placeholder: 'loginCheckJs（可空）',
              maxLines: 3,
            ),
            SourceEditValueFieldTile(
              title: 'JS 库',
              value: source.jsLib ?? '',
              onChanged: (value) => notifier.updateSource(
                (current) => current.copyWith(
                  jsLib: value.isEmpty ? null : value,
                ),
              ),
              placeholder: 'jsLib（可空）',
              maxLines: 2,
            ),
            SourceEditValueFieldTile(
              title: '封面解码 JS',
              value: source.coverDecodeJs ?? '',
              onChanged: (value) => notifier.updateSource(
                (current) => current.copyWith(
                  coverDecodeJs: value.isEmpty ? null : value,
                ),
              ),
              placeholder: 'coverDecodeJs（可空）',
              maxLines: 3,
            ),
            SourceEditValueFieldTile(
              title: '登录头缓存(JSON)',
              value: state.loginHeaderCache,
              onChanged: notifier.updateLoginHeaderCache,
              placeholder: '{"Cookie":"sid=...","Authorization":"Bearer ..."}',
              maxLines: 4,
            ),
            SourceEditValueFieldTile(
              title: '登录信息缓存',
              value: state.loginInfo,
              onChanged: notifier.updateLoginInfo,
              placeholder: 'userInfo（JSON 或文本，可空）',
              maxLines: 3,
            ),
            CupertinoListTile.notched(
              title: const Text('加载登录态缓存'),
              additionalInfo: state.loginStateLoading ? const Text('加载中…') : null,
              trailing: const CupertinoListTileChevron(),
              onTap: state.loginStateLoading ? null : () => actions.loadLoginState(),
            ),
            CupertinoListTile.notched(
              title: const Text('保存登录态缓存'),
              subtitle: const Text('保存 loginHeader/loginInfo 到本地缓存'),
              trailing: const CupertinoListTileChevron(),
              onTap: state.loginStateLoading ? null : () => actions.saveLoginState(),
            ),
            CupertinoListTile.notched(
              title: const Text('清除登录态缓存'),
              subtitle: const Text('清除当前书源的登录头与登录信息'),
              trailing: const CupertinoListTileChevron(),
              onTap: state.loginStateLoading ? null : () => actions.clearLoginState(),
            ),
          ],
        ),
        CupertinoListSection.insetGrouped(
          header: const Text('URL'),
          children: [
            SourceEditValueFieldTile(
              title: '书籍 URL 正则',
              value: source.bookUrlPattern ?? '',
              onChanged: (value) => notifier.updateSource(
                (current) => current.copyWith(
                  bookUrlPattern: value.isEmpty ? null : value,
                ),
              ),
              placeholder: 'bookUrlPattern（可空）',
            ),
            SourceEditValueFieldTile(
              title: '搜索 URL',
              value: source.searchUrl ?? '',
              onChanged: (value) => notifier.updateSource(
                (current) => current.copyWith(
                  searchUrl: value.isEmpty ? null : value,
                ),
              ),
              placeholder: 'searchUrl（含 {key} 或 {{key}}）',
            ),
            SourceEditValueFieldTile(
              title: '发现 URL',
              value: source.exploreUrl ?? '',
              onChanged: (value) => notifier.updateSource(
                (current) => current.copyWith(
                  exploreUrl: value.isEmpty ? null : value,
                ),
              ),
              placeholder: 'exploreUrl',
            ),
            SourceEditValueFieldTile(
              title: '发现屏蔽',
              value: source.exploreScreen ?? '',
              onChanged: (value) => notifier.updateSource(
                (current) => current.copyWith(
                  exploreScreen: value.isEmpty ? null : value,
                ),
              ),
              placeholder: 'exploreScreen（可空）',
            ),
          ],
        ),
        CupertinoListSection.insetGrouped(
          header: const Text('备注'),
          children: [
            SourceEditValueFieldTile(
              title: '书源备注',
              value: source.bookSourceComment ?? '',
              onChanged: (value) => notifier.updateSource(
                (current) => current.copyWith(
                  bookSourceComment: value.isEmpty ? null : value,
                ),
              ),
              placeholder: 'bookSourceComment（可空）',
              maxLines: 4,
            ),
            SourceEditValueFieldTile(
              title: '变量备注',
              value: source.variableComment ?? '',
              onChanged: (value) => notifier.updateSource(
                (current) => current.copyWith(
                  variableComment: value.isEmpty ? null : value,
                ),
              ),
              placeholder: 'variableComment（可空）',
              maxLines: 4,
            ),
          ],
        ),
        CupertinoListSection.insetGrouped(
          children: [
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
        if (state.jsonError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              state.jsonError!,
              style: TextStyle(
                color: CupertinoColors.systemRed.resolveFrom(context),
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }
}

String _sourceTypeLabel(int type) {
  switch (type) {
    case 1:
      return '音频';
    case 2:
      return '图片';
    case 3:
      return '文件';
    default:
      return '文本';
  }
}

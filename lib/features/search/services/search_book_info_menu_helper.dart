/// 搜索详情页菜单可见性辅助（对齐 legado `BookInfoActivity.onMenuOpened`）。
class SearchBookInfoMenuHelper {
  const SearchBookInfoMenuHelper._();

  /// legado 仅在 `bookSource.loginUrl` 非空时展示“登录”入口。
  static bool shouldShowLogin({
    required String? loginUrl,
  }) {
    return (loginUrl ?? '').trim().isNotEmpty;
  }

  /// legado 仅在“当前书籍是本地书”时展示“上传”入口。
  static bool shouldShowUpload({
    required bool isLocalBook,
  }) {
    return isLocalBook;
  }

  /// legado 仅在已匹配书源时展示“设置源变量”与“设置书籍变量”入口。
  static bool shouldShowSetVariable({
    required bool hasSource,
  }) {
    return hasSource;
  }

  /// legado 仅在已匹配书源时展示“允许更新”入口。
  static bool shouldShowAllowUpdate({
    required bool hasSource,
  }) {
    return hasSource;
  }

  /// legado 仅在“本地 TXT”时展示“分割长章节”入口。
  static bool shouldShowSplitLongChapter({
    required bool isLocalTxtBook,
  }) {
    return isLocalTxtBook;
  }
}

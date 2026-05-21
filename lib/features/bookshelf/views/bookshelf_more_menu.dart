// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_popover_menu.dart';
import 'bookshelf_add_by_url.dart';
import 'bookshelf_booklist_io.dart';
import 'bookshelf_catalog_actions.dart';
import 'bookshelf_layout_dialog.dart';
import 'bookshelf_local_import.dart';
import 'bookshelf_navigation.dart';
import 'bookshelf_scan_import.dart';
import 'bookshelf_view.dart';

extension BookshelfMoreMenu on BookshelfViewState {
  String updateCatalogMenuText() {
    if (isUpdatingCatalog) {
      return '更新目录（进行中）';
    }
    return '更新目录';
  }

  Future<void> showMoreMenu() async {
    final action = await showAppPopoverMenu<BookshelfMoreMenuAction>(
      context: context,
      anchorKey: moreMenuKey,
      items: [
        AppPopoverMenuItem(
          value: BookshelfMoreMenuAction.updateCatalog,
          icon: CupertinoIcons.refresh,
          label: updateCatalogMenuText(),
        ),
        const AppPopoverMenuItem(
          value: BookshelfMoreMenuAction.importLocal,
          icon: CupertinoIcons.folder,
          label: '添加本地',
        ),
        const AppPopoverMenuItem(
          value: BookshelfMoreMenuAction.remoteBook,
          icon: CupertinoIcons.cloud,
          label: '远程书籍',
        ),
        AppPopoverMenuItem(
          value: BookshelfMoreMenuAction.selectFolder,
          icon: CupertinoIcons.folder_open,
          label: isSelectingImportFolder ? '选择文件夹（进行中）' : '选择文件夹',
        ),
        const AppPopoverMenuItem(
          value: BookshelfMoreMenuAction.scanFolder,
          icon: CupertinoIcons.wand_rays,
          label: '智能扫描',
        ),
        const AppPopoverMenuItem(
          value: BookshelfMoreMenuAction.importFileNameRule,
          icon: CupertinoIcons.doc_text,
          label: '导入文件名',
        ),
        const AppPopoverMenuItem(
          value: BookshelfMoreMenuAction.addUrl,
          icon: CupertinoIcons.globe,
          label: '添加网址',
        ),
        const AppPopoverMenuItem(
          value: BookshelfMoreMenuAction.manage,
          icon: CupertinoIcons.square_list,
          label: '书架管理',
        ),
        const AppPopoverMenuItem(
          value: BookshelfMoreMenuAction.cacheExport,
          icon: CupertinoIcons.arrow_down_doc,
          label: '缓存/导出',
        ),
        const AppPopoverMenuItem(
          value: BookshelfMoreMenuAction.groupManage,
          icon: CupertinoIcons.folder_badge_plus,
          label: '分组管理',
        ),
        const AppPopoverMenuItem(
          value: BookshelfMoreMenuAction.layout,
          icon: CupertinoIcons.rectangle_grid_2x2,
          label: '书架布局',
        ),
        const AppPopoverMenuItem(
          value: BookshelfMoreMenuAction.exportBooklist,
          icon: CupertinoIcons.square_arrow_up,
          label: '导出书单',
        ),
        const AppPopoverMenuItem(
          value: BookshelfMoreMenuAction.importBooklist,
          icon: CupertinoIcons.square_arrow_down,
          label: '导入书单',
        ),
        const AppPopoverMenuItem(
          value: BookshelfMoreMenuAction.log,
          icon: CupertinoIcons.doc_plaintext,
          label: '日志',
        ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case BookshelfMoreMenuAction.updateCatalog:
        updateBookshelfCatalog();
        break;
      case BookshelfMoreMenuAction.importLocal:
        importLocalBook();
        break;
      case BookshelfMoreMenuAction.remoteBook:
        openRemoteBook();
        break;
      case BookshelfMoreMenuAction.selectFolder:
        selectImportFolder();
        break;
      case BookshelfMoreMenuAction.scanFolder:
        scanImportFolder();
        break;
      case BookshelfMoreMenuAction.importFileNameRule:
        showImportFileNameRuleDialog();
        break;
      case BookshelfMoreMenuAction.addUrl:
        showAddBookByUrlDialog();
        break;
      case BookshelfMoreMenuAction.manage:
        openBookshelfManage();
        break;
      case BookshelfMoreMenuAction.cacheExport:
        openCacheExport();
        break;
      case BookshelfMoreMenuAction.groupManage:
        openBookshelfGroupManageDialog();
        break;
      case BookshelfMoreMenuAction.layout:
        showLayoutConfigDialog();
        break;
      case BookshelfMoreMenuAction.exportBooklist:
        exportBookshelf();
        break;
      case BookshelfMoreMenuAction.importBooklist:
        showImportBookshelfDialog();
        break;
      case BookshelfMoreMenuAction.log:
        openAppLogDialog();
        break;
    }
  }
}

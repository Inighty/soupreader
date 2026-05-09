import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../models/book.dart';
import '../services/cache_download_task_service.dart';

/// 缓存进度卡片（仅在 [progress] 非空时显示）。
class CacheExportProgressCard extends StatelessWidget {
  const CacheExportProgressCard({super.key, required this.progress});

  final CacheDownloadProgress? progress;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    if (p == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground
            .resolveFrom(context),
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '正在缓存：${p.bookTitle}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            '当前书籍 ${p.completedChapters}/${p.requestedChapters} '
            '(新增${p.downloadedChapters}，已缓存${p.skippedChapters}，'
            '失败${p.failedChapters})',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '整体进度 新增${p.overallDownloadedChapters}，'
            '已缓存${p.overallSkippedChapters}，失败${p.overallFailedChapters}',
            style: TextStyle(
              fontSize: 12,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// 顶部「迁移中」提示卡片。
class CacheExportMigrationHintCard extends StatelessWidget {
  const CacheExportMigrationHintCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.tertiarySystemGroupedBackground
            .resolveFrom(context),
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
      ),
      child: Text(
        '缓存/导出（迁移中）',
        style: TextStyle(
          fontSize: 13,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
    );
  }
}

/// 单本书的卡片：标题/作者/状态 + 缓存按钮 + 导出按钮。
class CacheExportBookTile extends StatelessWidget {
  const CacheExportBookTile({
    super.key,
    required this.book,
    required this.cachedChapters,
    required this.downloadRunning,
    required this.exportRunning,
    required this.onDownload,
    required this.onExport,
  });

  final Book book;
  final int cachedChapters;
  final bool downloadRunning;
  final bool exportRunning;
  final VoidCallback onDownload;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final totalCount =
        book.totalChapters > 0 ? book.totalChapters : cachedChapters;
    final statusText =
        book.isLocal ? '本地书籍' : '已缓存 $cachedChapters/$totalCount';
    final secondaryLabel =
        CupertinoColors.secondaryLabel.resolveFrom(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground
            .resolveFrom(context),
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '作者：${book.author.isEmpty ? '未知' : book.author}',
                  style: TextStyle(fontSize: 13, color: secondaryLabel),
                ),
                const SizedBox(height: 4),
                Text(
                  '$statusText · 当前章节 ${book.currentChapter + 1}',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          if (!book.isLocal)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(44, 44),
              onPressed: downloadRunning ? null : onDownload,
              child: Icon(
                CupertinoIcons.cloud_download,
                size: 20,
                color: downloadRunning
                    ? secondaryLabel
                    : CupertinoColors.activeBlue.resolveFrom(context),
              ),
            ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(44, 44),
            onPressed: exportRunning ? null : onExport,
            child: Icon(
              CupertinoIcons.square_arrow_up,
              size: 20,
              color: secondaryLabel,
            ),
          ),
        ],
      ),
    );
  }
}

/// 顶部「下载/分组/更多」按钮组。
class CacheExportTopActions extends StatelessWidget {
  const CacheExportTopActions({
    super.key,
    required this.downloadRunning,
    required this.onDownloadTap,
    required this.onDownloadLongPress,
    required this.onBookGroupTap,
    required this.onMoreTap,
  });

  final bool downloadRunning;
  final VoidCallback onDownloadTap;
  final Future<void> Function() onDownloadLongPress;
  final VoidCallback onBookGroupTap;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onLongPress: onDownloadLongPress,
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onDownloadTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  downloadRunning
                      ? CupertinoIcons.stop_circle
                      : CupertinoIcons.cloud_download,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(downloadRunning ? '停止' : '下载'),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onBookGroupTap,
          child: const Icon(CupertinoIcons.square_grid_2x2, size: 20),
        ),
        const SizedBox(width: 8),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onMoreTap,
          child: const Icon(CupertinoIcons.ellipsis_circle, size: 20),
        ),
      ],
    );
  }
}

/// 顶部 nav middle：当前分组名称作为副标题。
class CacheExportNavMiddle extends StatelessWidget {
  const CacheExportNavMiddle({super.key, required this.groupTitle});

  final String groupTitle;

  @override
  Widget build(BuildContext context) {
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('缓存/导出'),
        Text(
          groupTitle,
          style: TextStyle(fontSize: 11, color: secondaryColor),
        ),
      ],
    );
  }
}

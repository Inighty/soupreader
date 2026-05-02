import '../models/book.dart';

/// 批量换源进度回调载体。
class BookshelfManageBatchChangeSourceProgress {
  final int current;
  final int total;
  final Book book;

  const BookshelfManageBatchChangeSourceProgress({
    required this.current,
    required this.total,
    required this.book,
  });

  String get progressText => '$current / $total';
}

/// 单本换源结果状态。
enum BookshelfManageBatchChangeSourceItemStatus {
  success,
  skipped,
  failed,
}

/// 单本换源动作内部结果。
class BatchChangeSourceItemResult {
  final BookshelfManageBatchChangeSourceItemStatus status;
  final String message;
  final bool cancelled;
  final bool applyDelay;

  const BatchChangeSourceItemResult._({
    required this.status,
    required this.message,
    required this.cancelled,
    required this.applyDelay,
  });

  const BatchChangeSourceItemResult.success({
    bool applyDelay = true,
  }) : this._(
          status: BookshelfManageBatchChangeSourceItemStatus.success,
          message: '',
          cancelled: false,
          applyDelay: applyDelay,
        );

  const BatchChangeSourceItemResult.skipped(
    String message, {
    bool applyDelay = false,
  }) : this._(
          status: BookshelfManageBatchChangeSourceItemStatus.skipped,
          message: message,
          cancelled: false,
          applyDelay: applyDelay,
        );

  const BatchChangeSourceItemResult.failed(
    String message, {
    bool applyDelay = false,
  }) : this._(
          status: BookshelfManageBatchChangeSourceItemStatus.failed,
          message: message,
          cancelled: false,
          applyDelay: applyDelay,
        );

  const BatchChangeSourceItemResult.cancelled()
      : this._(
          status: BookshelfManageBatchChangeSourceItemStatus.skipped,
          message: '已取消',
          cancelled: true,
          applyDelay: false,
        );
}

/// 批量换源汇总结果。
class BookshelfManageBatchChangeSourceSummary {
  final int totalCount;
  final int successCount;
  final int skippedCount;
  final int failedCount;
  final bool cancelled;
  final List<String> failedDetails;

  const BookshelfManageBatchChangeSourceSummary({
    required this.totalCount,
    required this.successCount,
    required this.skippedCount,
    required this.failedCount,
    required this.cancelled,
    required this.failedDetails,
  });
}

import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/cupertino_bottom_dialog.dart';

import '../../../core/services/exception_log_service.dart';

Future<void> showAppLogDialog(BuildContext context) {
  return showCupertinoBottomDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _AppLogDialog(),
  );
}

class _AppLogDialog extends StatelessWidget {
  const _AppLogDialog();

  @override
  Widget build(BuildContext context) {
    final service = ExceptionLogService();
    final screenSize = MediaQuery.sizeOf(context);
    final width = math.min(screenSize.width * 0.92, 520.0);
    final height = math.min(screenSize.height * 0.78, 620.0);
    final separator = CupertinoColors.separator.resolveFrom(context);

    return Center(
      child: CupertinoPopupSurface(
        child: SizedBox(
          width: width,
          height: height,
          child: CupertinoPageScaffold(
            backgroundColor:
                CupertinoColors.systemBackground.resolveFrom(context),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                    child: Row(
                      children: [
                        const SizedBox(width: 48),
                        const Expanded(
                          child: Text(
                            '日志',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          onPressed: service.clear,
                          child: const Text('清除'),
                          minimumSize: Size(30, 30),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 0.5, color: separator),
                  Expanded(
                    child: ValueListenableBuilder<List<ExceptionLogEntry>>(
                      valueListenable: service.listenable,
                      builder: (context, logs, _) {
                        if (logs.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          itemCount: logs.length,
                          separatorBuilder: (_, __) => Container(
                            height: 0.5,
                            color: separator,
                          ),
                          itemBuilder: (context, index) {
                            final entry = logs[index];
                            return _AppLogTile(entry: entry);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppLogTile extends StatelessWidget {
  final ExceptionLogEntry entry;

  const _AppLogTile({required this.entry});

  Future<void> _showStackTrace(BuildContext context) async {
    final stack = entry.stackTrace?.trim() ?? '';
    if (stack.isEmpty) return;
    await showCupertinoBottomDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Log'),
        content: SizedBox(
          width: 280,
          child: SingleChildScrollView(
            child: Text(
              stack,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showStackTrace(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatTime(entry.timestampMs),
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              entry.message,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTime(int timestampMs) {
  final date = DateTime.fromMillisecondsSinceEpoch(timestampMs).toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  String three(int value) => value.toString().padLeft(3, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} '
      '${two(date.hour)}:${two(date.minute)}:${two(date.second)}.${three(date.millisecond)}';
}

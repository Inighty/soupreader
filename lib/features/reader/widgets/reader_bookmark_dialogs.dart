import 'package:flutter/cupertino.dart';

import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/database/entities/bookmark_entity.dart';
import '../controllers/reader_bookmark_controller.dart';
import '../models/reader_view_models.dart';

/// Shows the "add bookmark" editor dialog.
///
/// Returns the user-entered text and note, or `null` if cancelled.
Future<ReaderBookmarkEditResult?> showBookmarkEditorDialog(
  BuildContext context,
  ReaderBookmarkDraft draft,
) async {
  final bookTextController = TextEditingController(text: draft.pageText);
  final noteController = TextEditingController();
  final result =
      await showCupertinoBottomSheetDialog<ReaderBookmarkEditResult>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: const Text('书签'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            draft.chapterTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          CupertinoTextField(
            controller: bookTextController,
            placeholder: '内容',
            maxLines: 3,
          ),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: noteController,
            placeholder: '备注',
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () {
            Navigator.pop(
              dialogContext,
              ReaderBookmarkEditResult(
                bookText: bookTextController.text,
                note: noteController.text,
              ),
            );
          },
          child: const Text('确定'),
        ),
      ],
    ),
  );
  bookTextController.dispose();
  noteController.dispose();
  return result;
}

/// Shows the "edit existing bookmark" dialog with delete option.
///
/// Returns `'saved'` if saved, `'deleted'` if deleted, or `null` if cancelled.
Future<String?> showEditBookmarkDialog(
  BuildContext context,
  BookmarkEntity bookmark, {
  required ReaderBookmarkController controller,
}) async {
  final textController = TextEditingController(text: bookmark.content);
  final result = await showCupertinoBottomSheetDialog<String>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(
        bookmark.chapterTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      content: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: CupertinoTextField(
          controller: textController,
          placeholder: '书签内容',
          maxLines: 4,
          minLines: 2,
        ),
      ),
      actions: [
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () async {
            await controller.remove(
              bookmark.id,
              bookmark.chapterIndex,
            );
            if (ctx.mounted) Navigator.pop(ctx, 'deleted');
          },
          child: const Text('删除'),
        ),
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx, 'saved'),
          child: const Text('保存'),
        ),
      ],
    ),
  );
  if (result == 'saved') {
    await controller.add(
      bookAuthor: bookmark.bookAuthor,
      chapterIndex: bookmark.chapterIndex,
      chapterTitle: bookmark.chapterTitle,
      chapterPos: bookmark.chapterPos,
      content: textController.text.trim(),
    );
  }
  textController.dispose();
  return result;
}

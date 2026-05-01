import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import 'package:soupreader/app/theme/typography.dart';
import 'package:soupreader/app/widgets/cupertino_bottom_dialog.dart';
import 'package:soupreader/features/source/services/source_import/selection_helper.dart';

class SourceListImportEditor {
  const SourceListImportEditor({
    required this.context,
  });

  final BuildContext context;

  Future<SourceImportCandidate?> editImportCandidateRawJson({
    required SourceImportCandidate candidate,
  }) async {
    final editedText = await editImportRawJsonText(initialText: candidate.rawJson);
    if (editedText == null) return null;
    return SourceImportSelectionHelper.tryReplaceCandidateRawJson(
      candidate: candidate,
      rawJson: editedText,
    );
  }

  Future<String?> editImportRawJsonText({
    required String initialText,
  }) async {
    final controller = TextEditingController(text: initialText);
    try {
      return await showCupertinoBottomSheetDialog<String>(
        context: context,
        builder: (popupContext) => CupertinoPopupSurface(
          isSurfacePainted: true,
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: math.min(MediaQuery.of(popupContext).size.height * 0.88, 760),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '编辑书源',
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          onPressed: () => Navigator.pop(popupContext, controller.text),
                          child: const Icon(CupertinoIcons.floppy_disk, size: 20),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 0.5,
                    color: CupertinoColors.separator.resolveFrom(popupContext),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: CupertinoTextField(
                        controller: controller,
                        minLines: null,
                        maxLines: null,
                        expands: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        keyboardType: TextInputType.multiline,
                        textAlignVertical: TextAlignVertical.top,
                        placeholder: '输入书源 JSON',
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamilyMonospace,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }
}

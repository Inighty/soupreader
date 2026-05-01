import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:soupreader/app/theme/typography.dart';
import 'package:soupreader/features/source/providers/source_edit_notifier.dart';
import 'package:soupreader/features/source/views/edit/actions/page_actions.dart';

class SourceEditJsonTab extends ConsumerStatefulWidget {
  const SourceEditJsonTab({
    super.key,
    required this.args,
    required this.actions,
  });

  final SourceEditArgs args;
  final SourceEditViewActions actions;

  @override
  ConsumerState<SourceEditJsonTab> createState() => _SourceEditJsonTabState();
}

class _SourceEditJsonTabState extends ConsumerState<SourceEditJsonTab> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(sourceEditProvider(widget.args)).rawJson,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sourceEditProvider(widget.args));
    if (_controller.text != state.rawJson) {
      _controller.value = _controller.value.copyWith(text: state.rawJson);
    }

    return Column(
      children: [
        if (state.jsonError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.exclamationmark_triangle_fill,
                  size: 16,
                  color: CupertinoColors.systemRed.resolveFrom(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.jsonError!,
                    style: TextStyle(
                      color: CupertinoColors.systemRed.resolveFrom(context),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: CupertinoTextField(
              controller: _controller,
              maxLines: null,
              minLines: 20,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamilyMonospace,
                fontSize: 13,
              ),
              onChanged: ref
                  .read(sourceEditProvider(widget.args).notifier)
                  .updateRawJson,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: CupertinoButton.filled(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  onPressed: widget.actions.formatJson,
                  child: const Text('格式化'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  onPressed: () => widget.actions.validateJson(),
                  child: const Text('校验'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

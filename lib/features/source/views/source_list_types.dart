import 'package:flutter/cupertino.dart';

import '../models/book_source.dart';

enum SourceSortMode {
  manual,
  weight,
  name,
  url,
  update,
  respond,
  enabled,
}

typedef SourceSortModeLabelBuilder = String Function(SourceSortMode mode);
typedef SourceSortChanged = void Function(SourceSortMode mode, bool ascending);
typedef SourceGroupManageCallback = void Function(BuildContext sheetContext);
typedef SourceGroupToggleCallback = void Function(BuildContext sheetContext);
typedef SourceGroupApplyQueryCallback = void Function(
  String query,
  BuildContext sheetContext,
);
typedef SourceMoveSourcesHandler = Future<void> Function(
  List<BookSource> sources, {
  required bool toTop,
});

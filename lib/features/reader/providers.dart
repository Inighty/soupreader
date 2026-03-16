import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'controllers/reader_bookmark_controller.dart';
import 'controllers/reader_read_aloud_controller.dart';
import 'controllers/reader_search_controller.dart';
import 'services/read_aloud_service.dart';

/// Creates a [ReaderReadAloudController] scoped to a specific reading session.
///
/// Must be overridden per-screen with the correct chapter switch callback
/// using `ProviderScope.overrides`.
///
/// Example:
/// ```dart
/// ProviderScope(
///   overrides: [
///     readerReadAloudProvider.overrideWith((ref) {
///       return ReaderReadAloudController(
///         settingsService: ref.read(settingsServiceProvider),
///         onRequestChapterSwitch: myChapterSwitchHandler,
///         onMessage: myToastHandler,
///       );
///     }),
///   ],
///   child: ...,
/// )
/// ```
final readerReadAloudProvider =
    Provider.autoDispose<ReaderReadAloudController>(
  (ref) => throw UnimplementedError(
    'readerReadAloudProvider must be overridden per reading session.',
  ),
);

/// Creates a [ReaderBookmarkController] scoped to a specific book.
///
/// Override with the correct bookId/bookTitle per-screen.
final readerBookmarkProvider =
    Provider.autoDispose<ReaderBookmarkController>(
  (ref) => throw UnimplementedError(
    'readerBookmarkProvider must be overridden per reading session.',
  ),
);

/// Creates a [ReaderSearchController] scoped to a specific reading session.
///
/// Override with the correct content loader and chapter accessors.
final readerSearchProvider =
    Provider.autoDispose<ReaderSearchController>(
  (ref) => throw UnimplementedError(
    'readerSearchProvider must be overridden per reading session.',
  ),
);

/// Factory for creating a [ReaderBookmarkController] for a given book.
///
/// Unlike the scoped provider above, this is a simple factory function for
/// use cases where Riverpod override scoping is not yet set up.
ReaderBookmarkController createBookmarkController({
  required String bookId,
  required String bookTitle,
}) {
  return ReaderBookmarkController(
    bookId: bookId,
    bookTitle: bookTitle,
  );
}

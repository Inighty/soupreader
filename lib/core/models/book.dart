/// Re-export [Book] and [Chapter] so that cross-feature consumers can
/// import from `core/models/` instead of reaching into
/// `features/bookshelf/models/`.
///
/// This is an intermediate step: the canonical source remains
/// `features/bookshelf/models/book.dart`. Once all external consumers are
/// migrated the classes may be physically moved here.
export '../../features/bookshelf/models/book.dart';

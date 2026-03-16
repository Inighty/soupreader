/// Re-export [BookSource] so that cross-feature consumers can import from
/// `core/models/` instead of reaching into `features/source/models/`.
///
/// This is an intermediate step: the canonical source remains
/// `features/source/models/book_source.dart`.
export '../../features/source/models/book_source.dart';

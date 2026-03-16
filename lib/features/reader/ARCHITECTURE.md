# Reader Feature Architecture

## Overview

The reader module implements the core reading experience, including chapter
loading, pagination, scrolling, TTS read-aloud, bookmarks, search, source
switching, and theme management.

## File Structure

```
reader/
├── controllers/          # Business logic (ChangeNotifier-based)
│   ├── reader_read_aloud_controller.dart   TTS engine lifecycle
│   ├── reader_bookmark_controller.dart     Bookmark CRUD + export
│   └── reader_search_controller.dart       Full-book search state machine
│
├── services/             # Pure functions and models
│   ├── reader_content_processor.dart       Text normalization (Legado-compat)
│   ├── reader_image_dimension_utils.dart   HTML/URL image size extraction
│   ├── reader_image_warmup_telemetry.dart  Probe telemetry models
│   └── reader_theme_resolver.dart          Theme color/font resolution
│
├── providers.dart        # Riverpod provider definitions (scoped per session)
│
├── views/
│   ├── simple_reader_view.dart             Core state + lifecycle + build()
│   ├── simple_reader_view_build.dart       [part] UI construction
│   ├── simple_reader_view_content.dart     [part] Content processing/warmup
│   ├── simple_reader_view_source_switch.dart [part] Source switching
│   ├── simple_reader_view_actions.dart     [part] User actions/utilities
│   ├── simple_reader_view_bookmark.dart    [part] Bookmark UI/catalog
│   ├── simple_reader_view_theme.dart       [part] Settings sync/theme getters
│   ├── simple_reader_view_scroll.dart      [part] Scroll mode Widget
│   └── simple_reader_view_types.dart       [part] Private data classes
│
├── models/               # Data models
├── widgets/              # Reusable widgets
└── shaders/              # GPU shaders (page curl)
```

## Extension-on-State Pattern

The view file uses Dart `part` files with `extension on _SimpleReaderViewState`
to physically distribute methods across files while maintaining full access to
private members (which are library-scoped in Dart).

```dart
// simple_reader_view.dart
part 'simple_reader_view_build.dart';

class _SimpleReaderViewState extends State<SimpleReaderView> { ... }

// simple_reader_view_build.dart
part of 'simple_reader_view.dart';

extension _BuildMethods on _SimpleReaderViewState {
  Widget _buildReadingContent() { ... }
}
```

Methods defined in extensions are automatically resolved by Dart when called
from within the class body (since there is no instance method with the same
name, the compiler falls through to extension methods in the same library).

## Controller Pattern

Controllers use `ChangeNotifier` and are instantiated in `initState()`:

```dart
_readAloudController = ReaderReadAloudController(
  settingsService: _settingsService,
  onRequestChapterSwitch: _handleReadAloudChapterSwitchRequest,
  onMessage: _handleReadAloudMessage,
);
_readAloudController.addListener(() { if (mounted) setState(() {}); });
```

The View listens to the controller and rebuilds on state changes. UI-only
concerns (toasts, dialogs) are communicated through callbacks.

## Testing

Unit tests cover pure-function services and controller logic:

```
test/features/reader/
├── controllers/
│   ├── reader_read_aloud_controller_test.dart
│   ├── reader_bookmark_controller_test.dart
│   └── reader_search_controller_test.dart
└── services/
    ├── reader_content_processor_test.dart
    ├── reader_image_dimension_utils_test.dart
    ├── reader_image_warmup_telemetry_test.dart
    └── reader_theme_resolver_test.dart
```

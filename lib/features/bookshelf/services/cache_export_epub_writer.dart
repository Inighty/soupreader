import 'dart:async';

import 'package:epubx/epubx.dart' as epub;

import '../models/book.dart';

/// 把章节列表生成 EPUB 字节流。
Future<List<int>> buildCacheExportEpubBytes({
  required Book book,
  required List<Chapter> cachedChapters,
  required Future<String> Function(String title) applyReplaceToTitle,
  required Future<String> Function(String content) applyReplaceToContent,
}) async {
  final title = book.title.trim().isEmpty ? '未命名书籍' : book.title.trim();
  final author = book.author.trim().isEmpty ? '未知' : book.author.trim();

  final content = epub.EpubContent();
  content.AllFiles!['Styles/main.css'] = epub.EpubTextContentFile()
    ..FileName = 'Styles/main.css'
    ..ContentType = epub.EpubContentType.CSS
    ..ContentMimeType = 'text/css'
    ..Content = _defaultEpubCss;

  final manifestItems = <epub.EpubManifestItem>[
    epub.EpubManifestItem()
      ..Id = 'ncx'
      ..Href = 'toc.ncx'
      ..MediaType = 'application/x-dtbncx+xml',
    epub.EpubManifestItem()
      ..Id = 'style'
      ..Href = 'Styles/main.css'
      ..MediaType = 'text/css',
  ];
  final spineItems = <epub.EpubSpineItemRef>[];
  final navPoints = <String>[];

  for (var i = 0; i < cachedChapters.length; i += 1) {
    final chapter = cachedChapters[i];
    final chapterNumber = i + 1;
    final chapterId = 'chapter_$chapterNumber';
    final chapterHref = 'Text/$chapterId.xhtml';
    final rawChapterTitle = chapter.title.trim().isEmpty
        ? '第$chapterNumber章'
        : chapter.title.trim();
    final chapterTitle = await applyReplaceToTitle(rawChapterTitle);
    final chapterContent =
        await applyReplaceToContent(chapter.content ?? '');
    manifestItems.add(
      epub.EpubManifestItem()
        ..Id = chapterId
        ..Href = chapterHref
        ..MediaType = 'application/xhtml+xml',
    );
    spineItems.add(
      epub.EpubSpineItemRef()
        ..IdRef = chapterId
        ..IsLinear = true,
    );
    navPoints.add(
      '<navPoint id="navPoint-$chapterNumber" playOrder="$chapterNumber">'
      '<navLabel><text>${_xmlEscapeText(chapterTitle)}</text></navLabel>'
      '<content src="${_xmlEscapeAttr(chapterHref)}" />'
      '</navPoint>',
    );
    content.AllFiles![chapterHref] = epub.EpubTextContentFile()
      ..FileName = chapterHref
      ..ContentType = epub.EpubContentType.XHTML_1_1
      ..ContentMimeType = 'application/xhtml+xml'
      ..Content = _buildEpubChapterDocument(
        title: chapterTitle,
        content: chapterContent,
      );
  }

  content.AllFiles!['toc.ncx'] = epub.EpubTextContentFile()
    ..FileName = 'toc.ncx'
    ..ContentType = epub.EpubContentType.DTBOOK_NCX
    ..ContentMimeType = 'application/x-dtbncx+xml'
    ..Content = _buildEpubTocNcx(title: title, navPoints: navPoints);

  final metadata = epub.EpubMetadata()
    ..Titles = <String>[title]
    ..Creators = <epub.EpubMetadataCreator>[
      epub.EpubMetadataCreator()..Creator = author,
    ]
    ..Publishers = <String>['SoupReader']
    ..Languages = <String>['zh'];
  final intro = (book.intro ?? '').trim();
  if (intro.isNotEmpty) {
    metadata.Description = intro;
  }

  final package = epub.EpubPackage()
    ..Version = epub.EpubVersion.Epub2
    ..Metadata = metadata
    ..Manifest = (epub.EpubManifest()..Items = manifestItems)
    ..Spine = (epub.EpubSpine()
      ..TableOfContents = 'ncx'
      ..Items = spineItems)
    ..Guide = epub.EpubGuide();
  final schema = epub.EpubSchema()
    ..Package = package
    ..ContentDirectoryPath = 'OEBPS';

  final epubBook = epub.EpubBook()
    ..Title = title
    ..Author = author
    ..Schema = schema
    ..Content = content;
  final bytes = epub.EpubWriter.writeBook(epubBook);
  if (bytes == null || bytes.isEmpty) {
    throw StateError('Epub 文件生成失败');
  }
  return bytes;
}

String _buildEpubTocNcx({
  required String title,
  required List<String> navPoints,
}) {
  final navPointText = navPoints.join('\n');
  return '''<?xml version="1.0" encoding="utf-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head>
    <meta name="dtb:uid" content="${_xmlEscapeAttr(title)}" />
    <meta name="dtb:depth" content="1" />
    <meta name="dtb:totalPageCount" content="0" />
    <meta name="dtb:maxPageNumber" content="0" />
  </head>
  <docTitle>
    <text>${_xmlEscapeText(title)}</text>
  </docTitle>
  <navMap>
$navPointText
  </navMap>
</ncx>
''';
}

String _buildEpubChapterDocument({
  required String title,
  required String content,
}) {
  final lines = content.split('\n');
  final paragraphBuffer = StringBuffer();
  if (lines.isEmpty) {
    paragraphBuffer.writeln('    <p>&#160;</p>');
  } else {
    var hasVisibleContent = false;
    for (final line in lines) {
      final text = line.trimRight();
      if (text.isEmpty) {
        paragraphBuffer.writeln('    <p>&#160;</p>');
        continue;
      }
      hasVisibleContent = true;
      paragraphBuffer.writeln('    <p>${_xmlEscapeText(text)}</p>');
    }
    if (!hasVisibleContent) {
      paragraphBuffer.writeln('    <p>&#160;</p>');
    }
  }
  return '''<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" lang="zh-CN">
  <head>
    <title>${_xmlEscapeText(title)}</title>
    <meta charset="utf-8" />
    <link rel="stylesheet" type="text/css" href="../Styles/main.css" />
  </head>
  <body>
    <h1>${_xmlEscapeText(title)}</h1>
${paragraphBuffer.toString()}  </body>
</html>
''';
}

String _xmlEscapeText(String raw) {
  return raw
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

String _xmlEscapeAttr(String raw) {
  return _xmlEscapeText(raw)
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

const String _defaultEpubCss = '''
body {
  margin: 0;
  padding: 1.2em;
  line-height: 1.8;
  font-size: 1em;
  color: #111;
  background: #fff;
  font-family: "Noto Serif SC", serif;
}
h1 {
  margin: 0 0 1em 0;
  font-size: 1.25em;
  line-height: 1.45;
}
p {
  margin: 0 0 0.8em 0;
  text-indent: 2em;
  white-space: pre-wrap;
  word-break: break-word;
}
''';

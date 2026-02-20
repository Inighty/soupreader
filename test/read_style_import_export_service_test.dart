import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:soupreader/features/reader/models/reading_settings.dart';
import 'package:soupreader/features/reader/services/read_style_import_export_service.dart';

void main() {
  Uint8List buildZip(
    Map<String, dynamic> json, {
    String name = 'readConfig.json',
    Map<String, List<int>> extraFiles = const <String, List<int>>{},
  }) {
    final content =
        utf8.encode(const JsonEncoder.withIndent('  ').convert(json));
    final archive = Archive();
    archive.addFile(ArchiveFile(name, content.length, content));
    extraFiles.forEach((entryName, bytes) {
      archive.addFile(ArchiveFile(entryName, bytes.length, bytes));
    });
    final encoded = ZipEncoder().encode(archive)!;
    return Uint8List.fromList(encoded);
  }

  test('buildExportZipBytes supports parse roundtrip', () async {
    final service = ReadStyleImportExportService();
    const input = ReadStyleConfig(
      name: '护眼',
      backgroundColor: 0xFFFDF6E3,
      textColor: 0xFF2D2D2D,
      bgType: ReadStyleConfig.bgTypeColor,
      bgStr: '#FDF6E3',
      bgAlpha: 92,
    );

    final bytes = service.buildExportZipBytes(input);
    final parsed = await service.parseZipBytes(bytes);

    expect(parsed.success, isTrue);
    expect(parsed.style, isNotNull);
    expect(parsed.style!.name, '护眼');
    expect(parsed.style!.backgroundColor, 0xFFFDF6E3);
    expect(parsed.style!.textColor, 0xFF2D2D2D);
    expect(parsed.style!.bgType, ReadStyleConfig.bgTypeColor);
    expect(parsed.style!.bgAlpha, 92);
    expect(parsed.warning, isNull);
  });

  test('parseZipBytes supports legacy bgStr/textColor fields', () async {
    final service = ReadStyleImportExportService();
    final bytes = buildZip(<String, dynamic>{
      'name': '夜间',
      'bgType': 0,
      'bgStr': '#000000',
      'textColor': '#ADADAD',
      'bgAlpha': 80,
    });

    final parsed = await service.parseZipBytes(bytes);
    expect(parsed.success, isTrue);
    expect(parsed.style, isNotNull);
    expect(parsed.style!.name, '夜间');
    expect(parsed.style!.backgroundColor, 0xFF000000);
    expect(parsed.style!.textColor, 0xFFADADAD);
    expect(parsed.style!.bgAlpha, 80);
  });

  test('parseZipBytes keeps bgType=1 asset background semantics', () async {
    final service = ReadStyleImportExportService();
    final bytes = buildZip(<String, dynamic>{
      'name': '纹理',
      'bgType': 1,
      'bgStr': 'paper.jpg',
      'textColor': '#222222',
    });

    final parsed = await service.parseZipBytes(bytes);
    expect(parsed.success, isTrue);
    expect(parsed.style, isNotNull);
    expect(parsed.style!.bgType, ReadStyleConfig.bgTypeAsset);
    expect(parsed.style!.bgStr, 'paper.jpg');
    expect(parsed.warning, isNull);
  });

  test('parseZipBytes restores bgType=2 background when image exists',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('read_style_bg_');
    addTearDown(() => tempDir.delete(recursive: true));
    final service = ReadStyleImportExportService(
      bgDirectoryResolver: () async => tempDir,
    );
    final bytes = buildZip(
      <String, dynamic>{
        'name': '图片样式',
        'bgType': 2,
        'bgStr': '/storage/emulated/0/Download/paper.jpg',
        'textColor': '#222222',
      },
      extraFiles: <String, List<int>>{
        'paper.jpg': <int>[1, 2, 3, 4],
      },
    );

    final parsed = await service.parseZipBytes(
      bytes,
      persistExternalBackground: true,
    );
    expect(parsed.success, isTrue);
    expect(parsed.style, isNotNull);
    expect(parsed.style!.bgType, ReadStyleConfig.bgTypeFile);
    expect(parsed.style!.bgStr, p.join(tempDir.path, 'paper.jpg'));
    expect(File(parsed.style!.bgStr).existsSync(), isTrue);
    expect(parsed.warning, isNull);
  });

  test('parseZipBytes warns and falls back when bgType=2 image is missing',
      () async {
    final service = ReadStyleImportExportService();
    final bytes = buildZip(<String, dynamic>{
      'name': '缺图样式',
      'bgType': 2,
      'bgStr': '/tmp/not-found.jpg',
      'textColor': '#111111',
      'backgroundColor': '#EFEFEF',
    });

    final parsed = await service.parseZipBytes(bytes);
    expect(parsed.success, isTrue);
    expect(parsed.style, isNotNull);
    expect(parsed.style!.bgType, ReadStyleConfig.bgTypeColor);
    expect(parsed.style!.backgroundColor, 0xFFEFEFEF);
    expect(parsed.warning, contains('背景图文件缺失'));
  });

  test('buildExportZipBytes keeps bgType=2 zip payload for parse', () async {
    final service = ReadStyleImportExportService();
    const style = ReadStyleConfig(
      name: '导出图样',
      bgType: ReadStyleConfig.bgTypeFile,
      bgStr: '/tmp/paper.jpg',
      textColor: 0xFF1A1A1A,
      backgroundColor: 0xFFF3E9D2,
    );
    final bytes = service.buildExportZipBytes(
      style,
      backgroundImageBytes: Uint8List.fromList(<int>[9, 8, 7, 6]),
      backgroundImageName: '/tmp/paper.jpg',
    );
    final parsed = await service.parseZipBytes(bytes);

    expect(parsed.success, isTrue);
    expect(parsed.style, isNotNull);
    expect(parsed.style!.bgType, ReadStyleConfig.bgTypeFile);
    expect(parsed.style!.bgStr, 'paper.jpg');
    expect(parsed.warning, isNull);
  });

  test('parseZipBytes fails when readConfig.json is missing', () async {
    final service = ReadStyleImportExportService();
    final bytes = buildZip(<String, dynamic>{
      'name': '无效',
    }, name: 'other.json');

    final parsed = await service.parseZipBytes(bytes);
    expect(parsed.success, isFalse);
    expect(parsed.errorMessage, contains('readConfig.json'));
  });
}

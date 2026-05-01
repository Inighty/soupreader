import 'dart:convert';

import 'package:flutter/cupertino.dart';

import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/providers/source_edit_notifier.dart';
import 'package:soupreader/features/source/services/source_debug/summary_parser.dart';

class SourceEditDebugHelper {
  static String? structuredSummaryText(SourceEditState state) {
    if (state.debugLinesAll.isEmpty) return null;
    return const JsonEncoder.withIndent('  ').convert(
      buildStructuredDebugSummary(state),
    );
  }

  static String? runtimeSnapshotText(SourceEditState state) {
    if (state.debugRuntimeVarsSnapshot.isEmpty) return null;
    return const JsonEncoder.withIndent('  ').convert(
      state.debugRuntimeVarsSnapshot,
    );
  }

  static Map<String, dynamic> buildStructuredDebugSummary(
    SourceEditState state,
  ) {
    final logLines = state.debugLinesAll.map((line) => line.text).toList();
    final errorLines = state.debugLinesAll
        .where((line) => line.state == -1)
        .map((line) => line.text)
        .toList();
    return SourceDebugSummaryParser.build(
      logLines: logLines,
      debugError: state.debugError,
      errorLines: errorLines,
    );
  }

  static List<String> diagnosisLabels(Map<String, dynamic> summary) {
    final diagnosis = summary['diagnosis'];
    if (diagnosis is! Map) return const <String>[];
    final raw = diagnosis['labels'];
    if (raw is! List) return const <String>[];
    return raw
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static List<String> diagnosisHints(Map<String, dynamic> summary) {
    final diagnosis = summary['diagnosis'];
    if (diagnosis is! Map) return const <String>[];
    final raw = diagnosis['hints'];
    if (raw is! List) return const <String>[];
    return raw
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static String buildMinimalReproText(SourceEditState state) {
    final source = state.source;
    final lines = <String>[
      '最小复现信息',
      '生成时间：${DateTime.now().toIso8601String()}',
      'Debug Key：${state.debugKey.trim().isEmpty ? '-' : state.debugKey.trim()}',
      '书源名称：${source.bookSourceName}',
      '书源地址：${source.bookSourceUrl}',
      if (state.debugError != null && state.debugError!.trim().isNotEmpty)
        '最近错误：${state.debugError!.trim()}',
    ];
    final tailLogs = state.debugLinesAll
        .map((line) => line.text)
        .where((text) => text.trim().isNotEmpty)
        .toList(growable: false);
    final start = tailLogs.length > 80 ? tailLogs.length - 80 : 0;
    if (tailLogs.isNotEmpty) {
      lines
        ..add('')
        ..add('关键日志（最近 ${tailLogs.length - start} 行）：')
        ..addAll(tailLogs.sublist(start));
    }
    return lines.join('\n');
  }

  static Color labelColor(BuildContext context, String code) {
    switch (code) {
      case 'request_failure':
      case 'parse_failure':
      case 'paging_interrupted':
        return CupertinoColors.systemRed.resolveFrom(context);
      case 'ok':
        return CupertinoColors.systemGreen.resolveFrom(context);
      default:
        return CupertinoColors.secondaryLabel.resolveFrom(context);
    }
  }

  static String labelText(String code) {
    switch (code) {
      case 'request_failure':
        return '请求失败';
      case 'parse_failure':
        return '解析失败';
      case 'paging_interrupted':
        return '分页中断';
      case 'ok':
        return '基本正常';
      case 'no_data':
        return '无数据';
      default:
        return code;
    }
  }

  static String resolveWebVerifyUrl(BookSource source, String key) {
    String abs(String url) {
      final trimmed = url.trim();
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        return trimmed;
      }
      if (trimmed.startsWith('//')) return 'https:$trimmed';
      if (trimmed.startsWith('/')) {
        final uri = Uri.parse(source.bookSourceUrl);
        return '${uri.scheme}://${uri.host}$trimmed';
      }
      return '${source.bookSourceUrl}$trimmed';
    }

    String buildSearchUrl(String template, String keyword) {
      var url = template;
      final encoded = Uri.encodeComponent(keyword);
      url = url.replaceAll('{{key}}', encoded);
      url = url.replaceAll('{key}', encoded);
      url = url.replaceAll('{{searchKey}}', encoded);
      url = url.replaceAll('{searchKey}', encoded);
      return url;
    }

    final trimmedKey = key.trim();
    if (trimmedKey.isEmpty) return source.bookSourceUrl;
    if (trimmedKey.startsWith('http://') || trimmedKey.startsWith('https://')) {
      return trimmedKey;
    }
    if (trimmedKey.contains('::')) {
      return abs(trimmedKey.substring(trimmedKey.indexOf('::') + 2));
    }
    if (trimmedKey.startsWith('++') || trimmedKey.startsWith('--')) {
      return abs(trimmedKey.substring(2));
    }
    if ((source.searchUrl ?? '').trim().isNotEmpty) {
      return abs(buildSearchUrl(source.searchUrl!.trim(), trimmedKey));
    }
    return source.bookSourceUrl;
  }

  static List<MapEntry<String, String>> parseExploreEntries({
    required BookSource source,
  }) {
    final result = <MapEntry<String, String>>[];
    final raw = (source.exploreUrl ?? '').trim();
    if (raw.isEmpty) return result;
    for (final part in raw.split(RegExp(r'(?:&&|\r?\n)+'))) {
      final text = part.trim();
      if (text.isEmpty) continue;
      final index = text.indexOf('::');
      if (index > 0) {
        final title = text.substring(0, index).trim();
        final url = text.substring(index + 2).trim();
        if (url.startsWith('http://') || url.startsWith('https://')) {
          result.add(MapEntry('$title::$url', '$title::$url'));
        }
      } else if (text.startsWith('http://') || text.startsWith('https://')) {
        result.add(MapEntry('发现::$text', '发现::$text'));
      }
    }
    return result;
  }
}

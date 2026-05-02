import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui show Size;

import '../../../core/models/book_source.dart';
import '../../../core/services/settings_service.dart';
import '../../source/services/rule_parser/rule_parser_engine.dart';
import '../services/reader_image_marker_codec.dart';
import '../services/reader_image_request_parser.dart';
import '../services/reader_image_warmup_telemetry.dart';
import 'reader_state.dart';

/// 图片预热 / 尺寸缓存 / Cookie 管理的纯逻辑委托。
///
/// 操作 [ImageCacheState]，不持有 BuildContext。
class ImageCoordinator {
  ImageCoordinator({
    required this.bookId,
    required this.isEphemeral,
    required this.image,
    required this.settingsService,
    required this.ruleEngine,
    required this.resolveCurrentSource,
    required this.recentFetchDuration,
  });

  final String bookId;
  final bool isEphemeral;
  final ImageCacheState image;
  final SettingsService settingsService;
  final RuleParserEngine ruleEngine;

  /// 返回当前活跃书源，可能为 null。
  final BookSource? Function() resolveCurrentSource;

  /// 最近一次章节内容拉取耗时（用于自适应预热预算）。
  final Duration Function() recentFetchDuration;

  static const int _persistedSnapshotMaxEntries = 120;
  static const double _longImageAspectRatioThreshold = 2.0;
  static const double _longImageErrorBoostThreshold = 0.22;

  // ═══════════════════════════════════════════════════════════════════
  // 快照恢复 / 持久化
  // ═══════════════════════════════════════════════════════════════════

  /// 从设置中恢复图片尺寸快照缓存。
  Future<void> restoreImageSizeSnapshot() async {
    if (isEphemeral) return;
    final rawSnapshot =
        settingsService.getBookReaderImageSizeSnapshot(bookId);
    if (rawSnapshot == null || rawSnapshot.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(rawSnapshot);
      if (decoded is! Map) return;
      final dynamic rawEntries = decoded['entries'] ?? decoded;
      if (rawEntries is! Map) return;
      final entries =
          rawEntries.map((key, value) => MapEntry('$key', value));
      ReaderImageMarkerCodec.restoreResolvedSizeCache(
        entries,
        clearBeforeRestore: false,
        maxEntries: _persistedSnapshotMaxEntries,
      );
      for (final rawKey in entries.keys) {
        final normalized =
            ReaderImageMarkerCodec.normalizeResolvedSizeKey(rawKey);
        if (normalized.isNotEmpty) {
          image.bookCacheKeys.add(normalized);
        }
      }
    } catch (_) {
      // 快照解析失败时不阻断阅读主流程。
    }
  }

  /// 延迟持久化图片尺寸快照。
  void schedulePersistSnapshot() {
    if (isEphemeral) return;
    image.snapshotPersistTimer?.cancel();
    image.snapshotPersistTimer = Timer(
      const Duration(milliseconds: 680),
      () {
        image.snapshotPersistTimer = null;
        unawaited(persistSnapshot());
      },
    );
  }

  /// 立即持久化图片尺寸快照。
  Future<void> persistSnapshot({bool force = false}) async {
    if (isEphemeral) return;
    if (!force && image.bookCacheKeys.isEmpty) return;
    try {
      final snapshot = ReaderImageMarkerCodec.snapshotResolvedSizeCache(
        keys: image.bookCacheKeys,
        maxEntries: _persistedSnapshotMaxEntries,
      );
      final payload = snapshot.isEmpty
          ? ''
          : jsonEncode(<String, dynamic>{
              'v': 1,
              'entries': snapshot,
            });
      await settingsService.saveBookReaderImageSizeSnapshot(
        bookId,
        payload,
      );
    } catch (_) {
      // 持久化失败不影响阅读链路。
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 尺寸缓存操作
  // ═══════════════════════════════════════════════════════════════════

  /// 记录图片缓存键用于后续快照持久化。
  void rememberBookImageCacheKey(String src) {
    final normalized =
        ReaderImageMarkerCodec.normalizeResolvedSizeKey(src);
    if (normalized.isEmpty) return;
    image.bookCacheKeys.add(normalized);
  }

  /// 查询当前章节的图片元数据。
  ReaderImageMarkerMeta? lookupImageMeta(String src) {
    final key =
        ReaderImageMarkerCodec.normalizeResolvedSizeKey(src);
    if (key.isEmpty) return null;
    return image.metaByCacheKey[key];
  }

  /// 处理分页模式图片尺寸解析回调。
  void handlePagedImageSizeResolved(String src, ui.Size size) {
    recordLongImageErrorSample(
      src: src,
      resolvedSize: size,
      hintMeta: lookupImageMeta(src),
    );
    schedulePersistSnapshot();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 长图首帧误差追踪
  // ═══════════════════════════════════════════════════════════════════

  /// 记录长图首帧纵横比误差样本（EMA）。
  void recordLongImageErrorSample({
    required String src,
    required ui.Size resolvedSize,
    ReaderImageMarkerMeta? hintMeta,
  }) {
    final width = resolvedSize.width;
    final height = resolvedSize.height;
    if (!width.isFinite ||
        !height.isFinite ||
        width <= 0 ||
        height <= 0) {
      return;
    }
    final actualRatio = height / width;
    if (!actualRatio.isFinite ||
        actualRatio <= _longImageAspectRatioThreshold) {
      return;
    }
    final hintedRatio = _hintMetaAspectRatio(hintMeta);
    final fallbackRatio = _fallbackFirstFrameAspectRatio();
    final expectedRatio = hintedRatio ?? fallbackRatio;
    if (!expectedRatio.isFinite || expectedRatio <= 0) return;

    final error =
        ((expectedRatio - actualRatio).abs() / actualRatio)
            .clamp(0.0, 1.0)
            .toDouble();
    if (!error.isFinite) return;

    if (image.longImageErrorSamples <= 0) {
      image.longImageErrorEma = error;
    } else {
      image.longImageErrorEma =
          image.longImageErrorEma * 0.78 + error * 0.22;
    }
    image.longImageErrorSamples =
        (image.longImageErrorSamples + 1).clamp(0, 4096);
    rememberBookImageCacheKey(src);
  }

  // ═══════════════════════════════════════════════════════════════════
  // Cookie 缓存
  // ═══════════════════════════════════════════════════════════════════

  /// 确保图片请求所需的 Cookie 已缓存。
  Future<void> ensureCookieHeaderCached(
    ReaderImageRequest request, {
    Duration timeout = const Duration(milliseconds: 120),
  }) async {
    final source = resolveCurrentSource();
    if (source == null || source.enabledCookieJar == false) return;

    final uri = Uri.tryParse(request.url);
    if (uri == null || !_isHttpLikeUri(uri)) return;
    final cookieKey = _cookieCacheKey(uri);
    if (image.cookieHeaderByHost.containsKey(cookieKey)) return;
    if (image.cookieLoadInFlight.contains(cookieKey)) return;

    image.cookieLoadInFlight.add(cookieKey);
    try {
      final future =
          RuleParserEngine.loadCookiesForUrl(uri.toString());
      final cookies = timeout > Duration.zero
          ? await future.timeout(timeout, onTimeout: () => const [])
          : await future;
      if (cookies.isEmpty) return;
      final cookieHeader = cookies
          .map((c) => '${c.name}=${c.value}')
          .where((s) => s.trim().isNotEmpty)
          .join('; ');
      if (cookieHeader.isEmpty) return;
      image.cookieHeaderByHost[cookieKey] = cookieHeader;
    } catch (_) {
      // Cookie 失败不阻断阅读。
    } finally {
      image.cookieLoadInFlight.remove(cookieKey);
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 预热预算
  // ═══════════════════════════════════════════════════════════════════

  /// 计算自适应预热预算。
  ///
  /// 根据最近拉取耗时、书源响应时间、长图误差 EMA、
  /// 遥测统计动态调整 probe 数量和超时时间。
  ReaderImageWarmupBudget resolveWarmupBudget({
    required int baseProbeCount,
    required Duration baseDuration,
  }) {
    var probeCount = baseProbeCount;
    var durationMs = baseDuration.inMilliseconds;
    final source = resolveCurrentSource();
    final telemetry = _telemetryForSource(source);

    final sampledMs = recentFetchDuration().inMilliseconds > 0
        ? recentFetchDuration().inMilliseconds
        : (source?.respondTime ?? 0);

    if (sampledMs > 0) {
      final boosted = durationMs + (sampledMs * 0.6).round();
      durationMs = boosted.clamp(durationMs, 980);
      if (sampledMs >= 900) {
        probeCount += 3;
      } else if (sampledMs >= 600) {
        probeCount += 2;
      } else if (sampledMs >= 350) {
        probeCount += 1;
      }
    }

    if ((source?.loginUrl ?? '').trim().isNotEmpty) {
      durationMs =
          (durationMs + 120).clamp(baseDuration.inMilliseconds, 980);
      probeCount += 1;
    }

    if (image.longImageErrorSamples >= 3 &&
        image.longImageErrorEma >= _longImageErrorBoostThreshold) {
      final errorBoostMs =
          (image.longImageErrorEma * 320).round().clamp(90, 260);
      durationMs = (durationMs + errorBoostMs)
          .clamp(baseDuration.inMilliseconds, 1200);
      probeCount += image.longImageErrorEma >= 0.45 ? 3 : 2;
    }

    if (telemetry != null && telemetry.sampleCount >= 3) {
      if (telemetry.timeoutRateEma >= 0.16 ||
          telemetry.timeoutStreak >= 2) {
        final timeoutBoostMs =
            (telemetry.timeoutRateEma * 420).round().clamp(70, 340) +
                telemetry.timeoutStreak * 45;
        durationMs = (durationMs + timeoutBoostMs)
            .clamp(baseDuration.inMilliseconds, 1450);
        probeCount += telemetry.timeoutRateEma >= 0.34 ? 3 : 2;
      }
      if (telemetry.authRateEma >= 0.10 ||
          telemetry.authStreak >= 1) {
        final authBoostMs =
            (120 + telemetry.authRateEma * 210).round().clamp(110, 280);
        durationMs = (durationMs + authBoostMs)
            .clamp(baseDuration.inMilliseconds, 1450);
        probeCount += telemetry.authRateEma >= 0.26 ? 2 : 1;
      }
      if (telemetry.decodeRateEma >= 0.16 ||
          telemetry.decodeStreak >= 2) {
        durationMs = (durationMs + 70)
            .clamp(baseDuration.inMilliseconds, 1450);
        probeCount += 1;
      }
      if (telemetry.successRateEma >= 0.78 &&
          telemetry.timeoutRateEma <= 0.06 &&
          telemetry.sampleCount >= 8) {
        probeCount -= 1;
      }
    }

    probeCount = probeCount.clamp(baseProbeCount, 18);
    final maxDuration = Duration(milliseconds: durationMs);
    var perProbeTimeoutMs = (durationMs * 0.46).round();
    if (telemetry != null && telemetry.sampleCount >= 3) {
      if (telemetry.timeoutRateEma >= 0.20 ||
          telemetry.timeoutStreak >= 2) {
        perProbeTimeoutMs += 70;
      }
      if (telemetry.authRateEma >= 0.12) {
        perProbeTimeoutMs += 40;
      }
    }
    final perProbeTimeout = Duration(
      milliseconds: perProbeTimeoutMs.clamp(180, 620),
    );
    return ReaderImageWarmupBudget(
      probeCount: probeCount,
      maxDuration: maxDuration,
      perProbeTimeout: perProbeTimeout,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 资源释放
  // ═══════════════════════════════════════════════════════════════════

  /// 记录一次 probe 成功。
  void recordProbeSuccess(BookSource? source) {
    _telemetryForSource(source)?.recordSuccess();
  }

  /// 记录一次 probe 失败。
  void recordProbeFailure(
    ReaderImageWarmupFailureKind kind,
    BookSource? source,
  ) {
    _telemetryForSource(source)?.recordFailure(kind);
  }

  // ═══════════════════════════════════════════════════════════════════
  // 资源释放
  // ═══════════════════════════════════════════════════════════════════

  void dispose() {
    image.snapshotPersistTimer?.cancel();
    image.snapshotPersistTimer = null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 私有
  // ═══════════════════════════════════════════════════════════════════

  double? _hintMetaAspectRatio(ReaderImageMarkerMeta? meta) {
    if (meta == null || !meta.hasDimensionHints) return null;
    final width = meta.width!;
    final height = meta.height!;
    if (!width.isFinite ||
        !height.isFinite ||
        width <= 0 ||
        height <= 0) {
      return null;
    }
    final ratio = height / width;
    if (!ratio.isFinite || ratio <= 0) return null;
    return ratio;
  }

  double _fallbackFirstFrameAspectRatio() {
    // 对齐 legado 的图片样式 fallback 值。
    switch (image.sourceUrl) {
      // 若未来需要根据 imageStyle 区分，可通过 settings 注入。
      default:
        return 0.62;
    }
  }

  ReaderImageWarmupSourceTelemetry? _telemetryForSource(
    BookSource? source,
  ) {
    if (source == null) return null;
    final key = source.bookSourceUrl;
    return image.telemetryBySource.putIfAbsent(
      key,
      () => ReaderImageWarmupSourceTelemetry(),
    );
  }

  String _cookieCacheKey(Uri uri) {
    return '${uri.scheme}://${uri.host}:${uri.port}';
  }

  bool _isHttpLikeUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }
}

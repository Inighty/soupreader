import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui show Size, instantiateImageCodec;

import 'package:flutter/painting.dart';

import '../../../core/models/book_source.dart';
import '../../source/services/rule_parser/rule_parser_engine.dart';
import '../../source/services/source/cover_loader.dart';
import '../services/reader_image_warmup_telemetry.dart';

/// 通过 [SourceCoverLoader] 加载图片字节并把异常归类为预热失败种类。
Future<ReaderImageBytesProbeResult> loadImageBytesFromSource({
  required BookSource source,
  required String imageUrl,
  required Duration timeout,
}) async {
  try {
    final bytes = await SourceCoverLoader.instance
        .load(imageUrl: imageUrl, source: source)
        .timeout(timeout);
    if (bytes == null || bytes.isEmpty) {
      return const ReaderImageBytesProbeResult.failure(
        ReaderImageWarmupFailureKind.other,
      );
    }
    return ReaderImageBytesProbeResult.success(bytes);
  } on TimeoutException {
    return const ReaderImageBytesProbeResult.failure(
      ReaderImageWarmupFailureKind.timeout,
    );
  } catch (error) {
    return ReaderImageBytesProbeResult.failure(
      ReaderImageWarmupErrorClassifier.classify(error),
    );
  }
}

/// 通过 [RuleParserEngine] 加载图片字节。
Future<ReaderImageBytesProbeResult> loadImageBytesFromRuleEngine({
  required RuleParserEngine ruleEngine,
  required BookSource source,
  required String imageUrl,
  required Duration timeout,
}) async {
  try {
    final bytes = await ruleEngine
        .fetchCoverBytes(source: source, imageUrl: imageUrl)
        .timeout(timeout);
    if (bytes == null || bytes.isEmpty) {
      return const ReaderImageBytesProbeResult.failure(
        ReaderImageWarmupFailureKind.other,
      );
    }
    return ReaderImageBytesProbeResult.success(bytes);
  } on TimeoutException {
    return const ReaderImageBytesProbeResult.failure(
      ReaderImageWarmupFailureKind.timeout,
    );
  } catch (error) {
    return ReaderImageBytesProbeResult.failure(
      ReaderImageWarmupErrorClassifier.classify(error),
    );
  }
}

/// 解码图片字节并返回原始尺寸；失败时返回 null。
Future<ui.Size?> decodeImageSizeFromBytes(Uint8List bytes) async {
  if (bytes.isEmpty) return null;
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final width = img.width.toDouble();
      final height = img.height.toDouble();
      img.dispose();
      if (!width.isFinite ||
          !height.isFinite ||
          width <= 0 ||
          height <= 0) {
        return null;
      }
      return ui.Size(width, height);
    } finally {
      codec.dispose();
    }
  } catch (_) {
    return null;
  }
}

/// 通过 [ImageProvider] 解析图片尺寸；超时或失败返回相应 [ReaderImageSizeProbeResult]。
Future<ReaderImageSizeProbeResult> resolveImageIntrinsicSize(
  ImageProvider<Object> imageProvider, {
  Duration timeout = const Duration(milliseconds: 220),
}) async {
  if (timeout <= Duration.zero) {
    return const ReaderImageSizeProbeResult.skipped();
  }
  final completer = Completer<ReaderImageSizeProbeResult>();
  final stream = imageProvider.resolve(const ImageConfiguration());
  ImageStreamListener? listener;
  Timer? timer;

  void finish(ReaderImageSizeProbeResult value) {
    if (completer.isCompleted) return;
    if (listener != null) stream.removeListener(listener);
    timer?.cancel();
    completer.complete(value);
  }

  listener = ImageStreamListener(
    (ImageInfo info, bool _) {
      final width = info.image.width.toDouble();
      final height = info.image.height.toDouble();
      if (!width.isFinite ||
          !height.isFinite ||
          width <= 0 ||
          height <= 0) {
        finish(const ReaderImageSizeProbeResult.failure(
          ReaderImageWarmupFailureKind.decode,
        ));
        return;
      }
      finish(
        ReaderImageSizeProbeResult.success(ui.Size(width, height)),
      );
    },
    onError: (Object error, StackTrace? stackTrace) {
      finish(ReaderImageSizeProbeResult.failure(
        ReaderImageWarmupErrorClassifier.classify(error),
      ));
    },
  );

  stream.addListener(listener);
  timer = Timer(
    timeout,
    () => finish(const ReaderImageSizeProbeResult.failure(
      ReaderImageWarmupFailureKind.timeout,
    )),
  );
  return completer.future;
}

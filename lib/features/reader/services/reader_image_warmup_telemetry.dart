import 'dart:ui' show Size;

/// Failure category for image warmup probes.
enum ReaderImageWarmupFailureKind {
  timeout,
  auth,
  decode,
  other,
}

/// Result of probing an image for its intrinsic size.
class ReaderImageSizeProbeResult {
  final Size? size;
  final ReaderImageWarmupFailureKind? failureKind;
  final bool attempted;

  const ReaderImageSizeProbeResult._({
    required this.size,
    required this.failureKind,
    required this.attempted,
  });

  const ReaderImageSizeProbeResult.success(Size value)
      : this._(size: value, failureKind: null, attempted: true);

  const ReaderImageSizeProbeResult.failure(ReaderImageWarmupFailureKind kind)
      : this._(size: null, failureKind: kind, attempted: true);

  const ReaderImageSizeProbeResult.skipped()
      : this._(size: null, failureKind: null, attempted: false);
}

/// Result of fetching raw image bytes during the warmup probe.
class ReaderImageBytesProbeResult {
  final dynamic bytes;
  final ReaderImageWarmupFailureKind? failureKind;

  const ReaderImageBytesProbeResult._({
    required this.bytes,
    required this.failureKind,
  });

  const ReaderImageBytesProbeResult.success(dynamic value)
      : this._(bytes: value, failureKind: null);

  const ReaderImageBytesProbeResult.failure(ReaderImageWarmupFailureKind kind)
      : this._(bytes: null, failureKind: kind);
}

/// Tracks success / failure rates for a specific image source during warmup.
///
/// Used to adaptively throttle warmup probes when a source is consistently
/// failing (timeout, auth, decode).
class ReaderImageWarmupSourceTelemetry {
  int sampleCount = 0;
  int timeoutStreak = 0;
  int authStreak = 0;
  int decodeStreak = 0;
  double successRateEma = 0.0;
  double timeoutRateEma = 0.0;
  double authRateEma = 0.0;
  double decodeRateEma = 0.0;
  DateTime updatedAt = DateTime.fromMillisecondsSinceEpoch(0);

  void recordSuccess() => _apply(success: true, failureKind: null);

  void recordFailure(ReaderImageWarmupFailureKind kind) =>
      _apply(success: false, failureKind: kind);

  void _apply({
    required bool success,
    required ReaderImageWarmupFailureKind? failureKind,
  }) {
    final alpha = sampleCount < 8 ? 0.34 : 0.18;
    successRateEma = _ema(successRateEma, success ? 1.0 : 0.0, alpha);
    timeoutRateEma = _ema(
      timeoutRateEma,
      failureKind == ReaderImageWarmupFailureKind.timeout ? 1.0 : 0.0,
      alpha,
    );
    authRateEma = _ema(
      authRateEma,
      failureKind == ReaderImageWarmupFailureKind.auth ? 1.0 : 0.0,
      alpha,
    );
    decodeRateEma = _ema(
      decodeRateEma,
      failureKind == ReaderImageWarmupFailureKind.decode ? 1.0 : 0.0,
      alpha,
    );

    if (success) {
      timeoutStreak = 0;
      authStreak = 0;
      decodeStreak = 0;
    } else {
      switch (failureKind) {
        case ReaderImageWarmupFailureKind.timeout:
          timeoutStreak = (timeoutStreak + 1).clamp(0, 24);
          authStreak = 0;
          decodeStreak = 0;
        case ReaderImageWarmupFailureKind.auth:
          authStreak = (authStreak + 1).clamp(0, 24);
          timeoutStreak = 0;
          decodeStreak = 0;
        case ReaderImageWarmupFailureKind.decode:
          decodeStreak = (decodeStreak + 1).clamp(0, 24);
          timeoutStreak = 0;
          authStreak = 0;
        case ReaderImageWarmupFailureKind.other:
        case null:
          timeoutStreak = 0;
          authStreak = 0;
          decodeStreak = 0;
      }
    }

    sampleCount = (sampleCount + 1).clamp(0, 4096);
    updatedAt = DateTime.now();
  }

  double _ema(double current, double value, double alpha) {
    if (sampleCount <= 0) return value;
    return current * (1 - alpha) + value * alpha;
  }
}

/// Budget for how many probes the warmup phase can execute and how long
/// it may take.
class ReaderImageWarmupBudget {
  final int probeCount;
  final Duration maxDuration;
  final Duration perProbeTimeout;

  const ReaderImageWarmupBudget({
    required this.probeCount,
    required this.maxDuration,
    required this.perProbeTimeout,
  });
}

/// Classifies a probe error into a [ReaderImageWarmupFailureKind].
class ReaderImageWarmupErrorClassifier {
  ReaderImageWarmupErrorClassifier._();

  static ReaderImageWarmupFailureKind classify(Object error) {
    final message = error.toString().toLowerCase();
    if (_looksLikeTimeout(message)) {
      return ReaderImageWarmupFailureKind.timeout;
    }
    if (_looksLikeAuthFailure(message)) {
      return ReaderImageWarmupFailureKind.auth;
    }
    if (_looksLikeDecodeFailure(message)) {
      return ReaderImageWarmupFailureKind.decode;
    }
    return ReaderImageWarmupFailureKind.other;
  }

  /// Merge two failure kinds, preferring the more specific one.
  static ReaderImageWarmupFailureKind merge(
    ReaderImageWarmupFailureKind? current,
    ReaderImageWarmupFailureKind candidate,
  ) {
    if (current == null) return candidate;
    if (current == candidate) return current;
    // Prefer the more specific failure kind.
    const priority = {
      ReaderImageWarmupFailureKind.auth: 3,
      ReaderImageWarmupFailureKind.timeout: 2,
      ReaderImageWarmupFailureKind.decode: 1,
      ReaderImageWarmupFailureKind.other: 0,
    };
    return (priority[candidate] ?? 0) > (priority[current] ?? 0)
        ? candidate
        : current;
  }

  static int? extractStatusCode(Object error) {
    final match = RegExp(r'status(?:\s*code)?[\s:=]*(\d{3})')
        .firstMatch(error.toString());
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  static bool _looksLikeTimeout(String message) =>
      message.contains('timeout') ||
      message.contains('timed out') ||
      message.contains('connection closed');

  static bool _looksLikeAuthFailure(String message) {
    final statusCode = _extractStatusCodeFromMessage(message);
    if (statusCode == 401 || statusCode == 403) return true;
    return message.contains('unauthorized') ||
        message.contains('forbidden') ||
        message.contains('access denied') ||
        message.contains('login required');
  }

  static bool _looksLikeDecodeFailure(String message) =>
      message.contains('codec') ||
      message.contains('decode') ||
      message.contains('invalid image') ||
      message.contains('not a valid');

  static int? _extractStatusCodeFromMessage(String message) {
    final match = RegExp(r'(\d{3})').firstMatch(message);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }
}


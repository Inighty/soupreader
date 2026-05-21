// ignore_for_file: invalid_use_of_protected_member

part of 'paged_reader_widget.dart';

extension _PagedReaderImageTracking on _PagedReaderWidgetState {
  void _trackPagedImageIntrinsicSize({
    required String src,
    required ImageProvider<Object> imageProvider,
  }) {
    final key = src.trim();
    if (key.isEmpty) return;
    if (ReaderImageMarkerCodec.lookupResolvedSize(key) != null) return;
    if (_imageSizeTrackingInFlight.contains(key)) return;

    _imageSizeTrackingInFlight.add(key);
    final stream = imageProvider.resolve(const ImageConfiguration());
    ImageStreamListener? listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        stream.removeListener(listener!);
        _imageSizeTrackingInFlight.remove(key);
        final changed = ReaderImageMarkerCodec.rememberResolvedSize(
          key,
          width: info.image.width.toDouble(),
          height: info.image.height.toDouble(),
        );
        if (changed && mounted) {
          widget.onImageSizeResolved?.call(
            key,
            Size(
              info.image.width.toDouble(),
              info.image.height.toDouble(),
            ),
          );
          widget.onImageSizeCacheUpdated?.call();
        }
      },
      onError: (Object error, StackTrace? stackTrace) {
        stream.removeListener(listener!);
        _imageSizeTrackingInFlight.remove(key);
      },
    );
    stream.addListener(listener);
  }
}

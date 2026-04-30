import 'package:aves/model/entry/entry.dart';
import 'package:aves/services/android_debug_service.dart';
import 'package:aves_model/aves_model.dart';
import 'package:aves_video/aves_video.dart';

class ExoVideoMetadataFetcher extends AvesVideoMetadataFetcher {
  static const _bitrateKey = 'Bitrate';
  static const _dateKey = 'Date';
  static const _durationKey = 'Duration';
  static const _imageHeightKey = 'Image Height';
  static const _imageRotationKey = 'Image Rotation';
  static const _imageWidthKey = 'Image Width';
  static const _titleKey = 'Title';
  static const _locationKey = 'Location';
  static const _videoFrameCountKey = 'Video Frame Count';
  static const _videoHeightKey = 'Video Height';
  static const _videoRotationKey = 'Video Rotation';
  static const _videoWidthKey = 'Video Width';
  static const _yearKey = 'Year';

  @override
  void init() {}

  @override
  Future<Map<String, Object?>> getMetadata(AvesEntryBase entry) async {
    if (entry is! AvesEntry) return {};

    final rawMetadata = await AndroidDebugService.getMediaMetadataRetrieverMetadata(entry);
    if (rawMetadata.isEmpty) return {};

    final fields = <String, Object?>{};

    final durationMillis = _tryParseInt(rawMetadata[_durationKey]);
    if (durationMillis != null && durationMillis > 0) {
      fields[Keys.duration] = Duration(milliseconds: durationMillis).toString();
      fields[Keys.durationMicros] = durationMillis * 1000;
    }

    _copyString(rawMetadata, _dateKey, fields, Keys.date);
    if (!fields.containsKey(Keys.date)) {
      _copyString(rawMetadata, _yearKey, fields, Keys.date);
    }
    _copyString(rawMetadata, _titleKey, fields, Keys.title);
    _copyString(rawMetadata, _locationKey, fields, Keys.location);
    _copyPositiveInt(rawMetadata, _bitrateKey, fields, Keys.bitrate);

    final videoWidth = _tryParseInt(rawMetadata[_videoWidthKey]) ?? _tryParseInt(rawMetadata[_imageWidthKey]);
    final videoHeight = _tryParseInt(rawMetadata[_videoHeightKey]) ?? _tryParseInt(rawMetadata[_imageHeightKey]);
    final rotationDegrees = _tryParseInt(rawMetadata[_videoRotationKey]) ?? _tryParseInt(rawMetadata[_imageRotationKey]);
    final frameCount = _tryParseInt(rawMetadata[_videoFrameCountKey]);

    final videoStream = <String, Object?>{
      Keys.streamType: MediaStreamTypes.video,
      Keys.index: 0,
    };
    if (videoWidth != null && videoWidth > 0) {
      videoStream[Keys.videoWidth] = videoWidth;
    }
    if (videoHeight != null && videoHeight > 0) {
      videoStream[Keys.videoHeight] = videoHeight;
    }
    if (rotationDegrees != null) {
      videoStream[Keys.rotate] = rotationDegrees;
    }
    if (frameCount != null && frameCount > 0) {
      videoStream[Keys.frameCount] = frameCount;
    }

    if (videoStream.length > 2) {
      fields[Keys.streams] = [videoStream];
    }

    return fields;
  }

  static void _copyPositiveInt(
    Map rawMetadata,
    String rawKey,
    Map<String, Object?> target,
    String targetKey,
  ) {
    final value = _tryParseInt(rawMetadata[rawKey]);
    if (value != null && value > 0) {
      target[targetKey] = value;
    }
  }

  static void _copyString(
    Map rawMetadata,
    String rawKey,
    Map<String, Object?> target,
    String targetKey,
  ) {
    final rawValue = rawMetadata[rawKey];
    if (rawValue is! String) return;

    final value = rawValue.trim();
    if (value.isNotEmpty) {
      target[targetKey] = value;
    }
  }

  static int? _tryParseInt(Object? rawValue) {
    if (rawValue is int) return rawValue;
    if (rawValue is num) return rawValue.round();
    if (rawValue is! String) return null;

    final value = rawValue.trim();
    if (value.isEmpty) return null;
    return int.tryParse(value);
  }
}

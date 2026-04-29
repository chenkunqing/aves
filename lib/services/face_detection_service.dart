import 'package:aves/services/common/channel.dart';

final FaceDetectionService faceDetectionService = FaceDetectionService._private();

class FaceDetectionService {
  static const _channel = AvesMethodChannel('deckers.thibault/aves/face_detection');

  FaceDetectionService._private();

  Future<FaceDetectionResult> detectFaces({
    required String uri,
    required String? mimeType,
    required int rotationDegrees,
    required int width,
    required int height,
  }) async {
    final result = await _channel.invokeMethod('detectFaces', <String, dynamic>{
      'uri': uri,
      'mimeType': mimeType,
      'rotationDegrees': rotationDegrees,
      'width': width,
      'height': height,
    });
    if (result is Map) {
      return FaceDetectionResult(
        faceCount: result['faceCount'] as int? ?? 0,
        boundingBoxes: result['boundingBoxes'] as String?,
      );
    }
    return const FaceDetectionResult(faceCount: 0);
  }
}

class FaceDetectionResult {
  final int faceCount;
  final String? boundingBoxes;

  const FaceDetectionResult({
    required this.faceCount,
    this.boundingBoxes,
  });
}

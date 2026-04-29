import 'dart:typed_data';

import 'package:aves/services/common/channel.dart';

final FaceRecognitionService faceRecognitionService = FaceRecognitionService._private();

class FaceRecognitionService {
  static const _channel = AvesMethodChannel('deckers.thibault/aves/face_recognition');

  FaceRecognitionService._private();

  Future<List<Uint8List>> extractEmbeddings({
    required String uri,
    required int width,
    required int height,
    required String boundingBoxes,
  }) async {
    final result = await _channel.invokeMethod('extractEmbeddings', <String, dynamic>{
      'uri': uri,
      'width': width,
      'height': height,
      'boundingBoxes': boundingBoxes,
    });
    if (result is Map) {
      final embeddings = result['embeddings'] as List?;
      if (embeddings != null) {
        return embeddings.map((e) => e as Uint8List).toList();
      }
    }
    return [];
  }
}

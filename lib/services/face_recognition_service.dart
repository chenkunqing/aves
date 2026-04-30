import 'dart:typed_data';

import 'package:aves/services/common/channel.dart';

final FaceRecognitionService faceRecognitionService = FaceRecognitionService._private();

class FaceRecognitionModel {
  final String version;
  final String assetPath;
  final int inputSize;
  final double matchThreshold;
  final double mergeThreshold;

  const FaceRecognitionModel({
    required this.version,
    required this.assetPath,
    required this.inputSize,
    required this.matchThreshold,
    required this.mergeThreshold,
  });

  factory FaceRecognitionModel.fromMap(Map<dynamic, dynamic> map) {
    return FaceRecognitionModel(
      version: map['modelVersion'] as String? ?? FaceRecognitionService.defaultModel.version,
      assetPath: map['assetPath'] as String? ?? FaceRecognitionService.defaultModel.assetPath,
      inputSize: map['inputSize'] as int? ?? FaceRecognitionService.defaultModel.inputSize,
      matchThreshold: (map['matchThreshold'] as num?)?.toDouble() ?? FaceRecognitionService.defaultModel.matchThreshold,
      mergeThreshold: (map['mergeThreshold'] as num?)?.toDouble() ?? FaceRecognitionService.defaultModel.mergeThreshold,
    );
  }
}

class FaceRecognitionResult {
  final FaceRecognitionModel model;
  final List<Uint8List> embeddings;

  const FaceRecognitionResult({
    required this.model,
    required this.embeddings,
  });
}

class FaceRecognitionService {
  static const _channel = AvesMethodChannel('deckers.thibault/aves/face_recognition');
  static const defaultModel = FaceRecognitionModel(
    version: 'mobilefacenet-112x112-192-v2-aligned',
    assetPath: 'models/mobilefacenet.tflite',
    inputSize: 112,
    matchThreshold: 0.55,
    mergeThreshold: 0.63,
  );

  FaceRecognitionModel? _model;

  FaceRecognitionService._private();

  Future<FaceRecognitionModel> getModel() async {
    final cachedModel = _model;
    if (cachedModel != null) return cachedModel;

    final result = await _channel.invokeMethod('getModelInfo');
    if (result is Map) {
      return _model = FaceRecognitionModel.fromMap(result);
    }
    return _model = defaultModel;
  }

  Future<FaceRecognitionResult> extractEmbeddings({
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
    final model = result is Map && result['modelInfo'] is Map ? FaceRecognitionModel.fromMap(result['modelInfo'] as Map) : await getModel();
    if (result is Map) {
      final embeddings = result['embeddings'] as List?;
      if (embeddings != null) {
        return FaceRecognitionResult(
          model: model,
          embeddings: embeddings.map((e) => e as Uint8List).toList(),
        );
      }
    }
    return FaceRecognitionResult(
      model: model,
      embeddings: const [],
    );
  }
}

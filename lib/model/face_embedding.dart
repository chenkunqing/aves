import 'dart:typed_data';

class FaceEmbeddingRow {
  final int? faceId;
  final int entryId;
  final String boundingBox;
  final Uint8List embedding;
  final String modelVersion;
  final int? personId;

  const FaceEmbeddingRow({
    this.faceId,
    required this.entryId,
    required this.boundingBox,
    required this.embedding,
    required this.modelVersion,
    this.personId,
  });

  factory FaceEmbeddingRow.fromMap(Map<String, Object?> map) {
    return FaceEmbeddingRow(
      faceId: map['faceId'] as int?,
      entryId: map['entryId'] as int,
      boundingBox: map['boundingBox'] as String,
      embedding: map['embedding'] as Uint8List,
      modelVersion: map['modelVersion'] as String? ?? '',
      personId: map['personId'] as int?,
    );
  }

  Map<String, Object?> toMap() => {
    if (faceId != null) 'faceId': faceId,
    'entryId': entryId,
    'boundingBox': boundingBox,
    'embedding': embedding,
    'modelVersion': modelVersion,
    'personId': personId,
  };

  FaceEmbeddingRow copyWith({String? modelVersion, int? personId}) {
    return FaceEmbeddingRow(
      faceId: faceId,
      entryId: entryId,
      boundingBox: boundingBox,
      embedding: embedding,
      modelVersion: modelVersion ?? this.modelVersion,
      personId: personId ?? this.personId,
    );
  }
}

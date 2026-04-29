import 'dart:typed_data';

class FaceEmbeddingRow {
  final int? faceId;
  final int entryId;
  final String boundingBox;
  final Uint8List embedding;
  final int? personId;

  const FaceEmbeddingRow({
    this.faceId,
    required this.entryId,
    required this.boundingBox,
    required this.embedding,
    this.personId,
  });

  factory FaceEmbeddingRow.fromMap(Map<String, Object?> map) {
    return FaceEmbeddingRow(
      faceId: map['faceId'] as int?,
      entryId: map['entryId'] as int,
      boundingBox: map['boundingBox'] as String,
      embedding: map['embedding'] as Uint8List,
      personId: map['personId'] as int?,
    );
  }

  Map<String, Object?> toMap() => {
        if (faceId != null) 'faceId': faceId,
        'entryId': entryId,
        'boundingBox': boundingBox,
        'embedding': embedding,
        'personId': personId,
      };

  FaceEmbeddingRow copyWith({int? personId}) {
    return FaceEmbeddingRow(
      faceId: faceId,
      entryId: entryId,
      boundingBox: boundingBox,
      embedding: embedding,
      personId: personId ?? this.personId,
    );
  }
}

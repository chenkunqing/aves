import 'dart:math';
import 'dart:typed_data';

class FaceClustering {
  static List<double> bytesToEmbedding(Uint8List bytes) {
    final dim = bytes.lengthInBytes ~/ 4;
    final float32 = Float32List.view(bytes.buffer, bytes.offsetInBytes, dim);
    return float32.toList();
  }

  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0;
    double dot = 0, normA = 0, normB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0;
    return dot / (sqrt(normA) * sqrt(normB));
  }

  static int? findMatchingPerson(
    List<double> faceEmbedding,
    Map<int, List<double>> personCentroids,
    double similarityThreshold,
  ) {
    int? bestPersonId;
    var bestSimilarity = similarityThreshold;
    for (final entry in personCentroids.entries) {
      final similarity = cosineSimilarity(faceEmbedding, entry.value);
      if (similarity > bestSimilarity) {
        bestSimilarity = similarity;
        bestPersonId = entry.key;
      }
    }
    return bestPersonId;
  }

  static List<double> updateCentroid(List<double> centroid, int sampleCount, List<double> embedding) {
    if (centroid.isEmpty) return List.of(embedding);
    final dim = centroid.length;
    final updated = List<double>.filled(dim, 0);
    final weight = sampleCount.toDouble();
    for (var i = 0; i < dim; i++) {
      updated[i] = (centroid[i] * weight + embedding[i]) / (weight + 1);
    }
    return normalize(updated);
  }

  static List<double> combineCentroids(List<double> centroidA, int sampleCountA, List<double> centroidB, int sampleCountB) {
    if (centroidA.isEmpty) return List.of(centroidB);
    if (centroidB.isEmpty) return List.of(centroidA);
    final dim = centroidA.length;
    final updated = List<double>.filled(dim, 0);
    final total = (sampleCountA + sampleCountB).toDouble();
    for (var i = 0; i < dim; i++) {
      updated[i] = (centroidA[i] * sampleCountA + centroidB[i] * sampleCountB) / total;
    }
    return normalize(updated);
  }

  static List<double> computeCentroid(List<List<double>> embeddings) {
    if (embeddings.isEmpty) return [];
    final dim = embeddings.first.length;
    final centroid = List.filled(dim, 0.0);
    for (final emb in embeddings) {
      for (int i = 0; i < dim; i++) {
        centroid[i] += emb[i];
      }
    }
    final n = embeddings.length.toDouble();
    for (int i = 0; i < dim; i++) {
      centroid[i] /= n;
    }
    return normalize(centroid);
  }

  static List<double> normalize(List<double> embedding) {
    var norm = 0.0;
    for (final value in embedding) {
      norm += value * value;
    }
    norm = sqrt(norm);
    if (norm == 0) return embedding;
    return embedding.map((value) => value / norm).toList(growable: false);
  }
}

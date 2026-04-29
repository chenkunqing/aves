import 'dart:math';
import 'dart:typed_data';

class FaceClustering {
  static const double similarityThreshold = 0.40;

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
  ) {
    int? bestPersonId;
    double bestSimilarity = similarityThreshold;
    for (final entry in personCentroids.entries) {
      final similarity = cosineSimilarity(faceEmbedding, entry.value);
      if (similarity > bestSimilarity) {
        bestSimilarity = similarity;
        bestPersonId = entry.key;
      }
    }
    return bestPersonId;
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
    double norm = 0;
    for (int i = 0; i < dim; i++) {
      norm += centroid[i] * centroid[i];
    }
    norm = sqrt(norm);
    if (norm > 0) {
      for (int i = 0; i < dim; i++) {
        centroid[i] /= norm;
      }
    }
    return centroid;
  }
}

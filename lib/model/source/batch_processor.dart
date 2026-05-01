import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/source/analysis_controller.dart';

class BatchProcessor {
  final int commitThreshold;
  final int stopCheckThreshold;

  const BatchProcessor({
    required this.commitThreshold,
    required this.stopCheckThreshold,
  });

  Future<void> run<T>({
    required AnalysisController controller,
    required Iterable<AvesEntry> entries,
    required Future<T?> Function(AvesEntry entry) process,
    required Future<void> Function(Set<T> batch) onCommit,
    required void Function(int done, int total) onProgress,
    int progressOffset = 0,
    int? progressTotal,
  }) async {
    var progressDone = progressOffset;
    final total = progressTotal ?? entries.length;
    onProgress(progressDone, total);

    var stopCheckCount = 0;
    final batch = <T>{};
    for (final entry in entries) {
      final result = await process(entry);
      if (result != null) {
        batch.add(result);
        if (batch.length >= commitThreshold) {
          await onCommit(Set.unmodifiable(batch));
          batch.clear();
        }
      }
      if (++stopCheckCount >= stopCheckThreshold) {
        stopCheckCount = 0;
        if (controller.isStopping) return;
      }
      onProgress(++progressDone, total);
    }
    if (batch.isNotEmpty) {
      await onCommit(Set.unmodifiable(batch));
    }
  }
}

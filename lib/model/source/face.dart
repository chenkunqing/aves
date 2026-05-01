import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/entry/extensions/props.dart';
import 'package:aves/model/entry_faces.dart';
import 'package:aves/model/source/analysis_controller.dart';
import 'package:aves/model/source/batch_processor.dart';
import 'package:aves/model/source/collection_source.dart';
import 'package:aves/services/common/services.dart';
import 'package:aves/services/face_detection_service.dart';
import 'package:aves_model/aves_model.dart';
import 'package:flutter/foundation.dart';

mixin FaceMixin on SourceBase {
  static const _batch = BatchProcessor(commitThreshold: 200, stopCheckThreshold: 50);

  static bool faceDetectionTest(AvesEntry entry) => entry.isImage && !entryFaces.isScanned(entry.id);

  Future<void> detectFaces(AnalysisController controller, Set<AvesEntry> candidateEntries) async {
    if (controller.isStopping) return;

    final force = controller.force;
    final todo = (force ? candidateEntries.where((e) => e.isImage) : candidateEntries.where(faceDetectionTest)).toSet();
    if (todo.isEmpty) return;

    state = SourceState.detectingFaces;

    await _batch.run<int>(
      controller: controller,
      entries: todo,
      process: (entry) async {
        try {
          final result = await faceDetectionService.detectFaces(
            uri: entry.uri,
            mimeType: entry.mimeType,
            rotationDegrees: entry.rotationDegrees,
            width: entry.width,
            height: entry.height,
          );
          await entryFaces.save(entry.id, result.faceCount, result.boundingBoxes);
          return entry.id;
        } catch (e) {
          debugPrint('face detection failed for entry id=${entry.id} uri=${entry.uri}: $e');
          return null;
        }
      },
      onCommit: (_) async {
        await deviceService.requestGarbageCollection();
      },
      onProgress: (done, total) => setProgress(done: done, total: total),
    );
  }
}

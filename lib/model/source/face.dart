import 'dart:convert';
import 'dart:typed_data';

import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/entry/extensions/props.dart';
import 'package:aves/model/entry_faces.dart';
import 'package:aves/model/face_embedding.dart';
import 'package:aves/model/source/analysis_controller.dart';
import 'package:aves/model/source/collection_source.dart';
import 'package:aves/services/common/services.dart';
import 'package:aves/services/face_detection_service.dart';
import 'package:aves/services/face_recognition_service.dart';
import 'package:aves_model/aves_model.dart';
import 'package:flutter/foundation.dart';

mixin FaceMixin on SourceBase {
  static const commitCountThreshold = 200;
  static const _stopCheckCountThreshold = 50;

  static bool faceDetectionTest(AvesEntry entry) => entry.isImage && !entryFaces.isScanned(entry.id);

  Future<void> detectFaces(AnalysisController controller, Set<AvesEntry> candidateEntries) async {
    if (controller.isStopping) return;

    final force = controller.force;
    final todo = (force ? candidateEntries.where((e) => e.isImage) : candidateEntries.where(faceDetectionTest)).toSet();
    if (todo.isEmpty) return;

    state = SourceState.detectingFaces;
    var progressDone = 0;
    final progressTotal = todo.length;
    setProgress(done: progressDone, total: progressTotal);

    var stopCheckCount = 0;
    var commitCount = 0;
    for (final entry in todo) {
      try {
        final result = await faceDetectionService.detectFaces(
          uri: entry.uri,
          mimeType: entry.mimeType,
          rotationDegrees: entry.rotationDegrees,
          width: entry.width,
          height: entry.height,
        );
        await entryFaces.save(entry.id, result.faceCount, result.boundingBoxes);

        if (result.faceCount > 0 && result.boundingBoxes != null) {
          try {
            final recognitionResult = await faceRecognitionService.extractEmbeddings(
              uri: entry.uri,
              width: entry.width,
              height: entry.height,
              boundingBoxes: result.boundingBoxes!,
            );
            final rows = _buildFaceEmbeddings(
              entryId: entry.id,
              boundingBoxes: result.boundingBoxes!,
              embeddings: recognitionResult.embeddings,
              modelVersion: recognitionResult.model.version,
            );
            if (rows.isNotEmpty) {
              await localMediaDb.saveFaceEmbeddings(entry.id, rows);
            }
          } catch (e) {
            debugPrint('face embedding extraction failed for entry id=${entry.id}: $e');
          }
        }

        commitCount++;
        if (commitCount >= commitCountThreshold) {
          commitCount = 0;
          await deviceService.requestGarbageCollection();
        }
      } catch (e) {
        debugPrint('face detection failed for entry id=${entry.id} uri=${entry.uri}: $e');
      }

      if (++stopCheckCount >= _stopCheckCountThreshold) {
        stopCheckCount = 0;
        if (controller.isStopping) return;
      }
      setProgress(done: ++progressDone, total: progressTotal);
    }
  }

  Future<void> extractMissingEmbeddings(AnalysisController controller) async {
    if (controller.isStopping) return;

    final model = await faceRecognitionService.getModel();
    final missing = await localMediaDb.loadEntryFacesNeedingEmbeddings(model.version);
    if (missing.isEmpty) return;

    state = SourceState.detectingFaces;
    var progressDone = 0;
    final progressTotal = missing.length;
    setProgress(done: progressDone, total: progressTotal);

    for (final entry in missing.entries) {
      if (controller.isStopping) return;

      final entryId = entry.key;
      final avesEntry = getEntryById(entryId);
      if (avesEntry == null) {
        setProgress(done: ++progressDone, total: progressTotal);
        continue;
      }

      try {
        var boundingBoxes = entry.value;
        if (_needsFaceRedetection(boundingBoxes)) {
          final detectionResult = await faceDetectionService.detectFaces(
            uri: avesEntry.uri,
            mimeType: avesEntry.mimeType,
            rotationDegrees: avesEntry.rotationDegrees,
            width: avesEntry.width,
            height: avesEntry.height,
          );
          if (detectionResult.faceCount <= 0 || detectionResult.boundingBoxes == null) {
            setProgress(done: ++progressDone, total: progressTotal);
            continue;
          }
          boundingBoxes = detectionResult.boundingBoxes!;
          await entryFaces.save(entryId, detectionResult.faceCount, boundingBoxes);
        }

        final recognitionResult = await faceRecognitionService.extractEmbeddings(
          uri: avesEntry.uri,
          width: avesEntry.width,
          height: avesEntry.height,
          boundingBoxes: boundingBoxes,
        );
        final rows = _buildFaceEmbeddings(
          entryId: entryId,
          boundingBoxes: boundingBoxes,
          embeddings: recognitionResult.embeddings,
          modelVersion: recognitionResult.model.version,
        );
        if (rows.isNotEmpty) {
          await localMediaDb.saveFaceEmbeddings(entryId, rows);
        }
      } catch (e) {
        debugPrint('face embedding extraction failed for entry id=$entryId: $e');
      }

      setProgress(done: ++progressDone, total: progressTotal);
    }
  }

  bool _needsFaceRedetection(String boundingBoxes) {
    try {
      final boxesJson = jsonDecode(boundingBoxes) as List;
      if (boxesJson.isEmpty) return true;
      return boxesJson.any((box) {
        if (box is! Map) return true;
        final landmarks = box['landmarks'];
        if (landmarks is! Map) return true;
        return landmarks['leftEye'] == null || landmarks['rightEye'] == null || landmarks['nose'] == null;
      });
    } catch (_) {
      return true;
    }
  }

  List<FaceEmbeddingRow> _buildFaceEmbeddings({
    required int entryId,
    required String boundingBoxes,
    required List<Uint8List> embeddings,
    required String modelVersion,
  }) {
    final boxesJson = jsonDecode(boundingBoxes) as List;
    final rowCount = embeddings.length < boxesJson.length ? embeddings.length : boxesJson.length;
    return List.generate(
      rowCount,
      (index) => FaceEmbeddingRow(
        entryId: entryId,
        boundingBox: jsonEncode(boxesJson[index]),
        embedding: embeddings[index],
        modelVersion: modelVersion,
      ),
    );
  }
}

import 'dart:convert';

import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/face_clustering.dart';
import 'package:aves/model/face_embedding.dart';
import 'package:aves/model/filters/person.dart';
import 'package:aves/model/person.dart';
import 'package:aves/model/source/analysis_controller.dart';
import 'package:aves/model/source/collection_source.dart';
import 'package:aves/services/common/services.dart';
import 'package:aves_model/aves_model.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

mixin PersonMixin on SourceBase {
  List<int> sortedPersonIds = List.unmodifiable([]);

  Future<void> loadPersonData() async {
    await personStore.init();
    updatePersons();
  }

  Future<void> clusterFaces(AnalysisController controller) async {
    if (controller.isStopping) return;

    // always re-cluster from scratch to use the latest threshold
    await _resetClustering();

    final allFaces = await localMediaDb.loadUnassignedFaceEmbeddings();
    if (allFaces.isEmpty) return;

    state = SourceState.clusteringFaces;
    var progressDone = 0;
    final progressTotal = allFaces.length;
    setProgress(done: progressDone, total: progressTotal);

    final personCentroids = <int, List<double>>{};
    final personBestFace = <int, (int entryId, String boundingBox, double area)>{};

    for (final face in allFaces) {
      if (controller.isStopping) return;

      try {
        final embedding = FaceClustering.bytesToEmbedding(face.embedding);
        var matchedPersonId = FaceClustering.findMatchingPerson(embedding, personCentroids);

        if (matchedPersonId == null) {
          final personCount = personStore.personCount;
          matchedPersonId = await personStore.addPerson(PersonRow(
            name: '人物 ${personCount + 1}',
            coverEntryId: face.entryId,
          ));
          personCentroids[matchedPersonId] = embedding;
        } else {
          final existingEmbeddings = personCentroids[matchedPersonId];
          if (existingEmbeddings != null) {
            personCentroids[matchedPersonId] = FaceClustering.computeCentroid([existingEmbeddings, embedding]);
          }
        }

        if (face.faceId != null) {
          await localMediaDb.updateFaceEmbeddingPersonId(face.faceId!, matchedPersonId);
        }
        personStore.assignFaceToPersonInCache(face.entryId, matchedPersonId, boundingBox: face.boundingBox);

        final faceArea = _computeFaceArea(face.boundingBox);
        final best = personBestFace[matchedPersonId];
        if (best == null || faceArea > best.$3) {
          personBestFace[matchedPersonId] = (face.entryId, face.boundingBox, faceArea);
        }
      } catch (e) {
        debugPrint('face clustering failed for faceId=${face.faceId} entryId=${face.entryId}: $e');
      }

      setProgress(done: ++progressDone, total: progressTotal);
    }

    // update cover to the entry with the largest face for each person
    for (final entry in personBestFace.entries) {
      final person = personStore.getById(entry.key);
      if (person != null) {
        final updated = person.copyWith(coverEntryId: entry.value.$1);
        await personStore.updatePerson(updated);
        personStore.setCoverBoundingBox(entry.key, entry.value.$2);
      }
    }

    // merge pass: merge persons whose centroids are too similar
    await _mergeClosePersons(personCentroids);

    updatePersons();
  }

  double _computeFaceArea(String boundingBoxJson) {
    try {
      final bbox = jsonDecode(boundingBoxJson) as Map<String, dynamic>;
      final w = ((bbox['right'] as num) - (bbox['left'] as num)).toDouble();
      final h = ((bbox['bottom'] as num) - (bbox['top'] as num)).toDouble();
      return w * h;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _resetClustering() async {
    await localMediaDb.resetAllFaceEmbeddingPersonIds();
    await localMediaDb.clearPersons();
    personStore.resetCache();
  }

  Future<void> _mergeClosePersons(Map<int, List<double>> personCentroids) async {
    const mergeThreshold = 0.45;
    final personIds = personCentroids.keys.toList();
    for (int i = 0; i < personIds.length; i++) {
      for (int j = i + 1; j < personIds.length; j++) {
        final idA = personIds[i];
        final idB = personIds[j];
        if (!personCentroids.containsKey(idA) || !personCentroids.containsKey(idB)) continue;
        final similarity = FaceClustering.cosineSimilarity(personCentroids[idA]!, personCentroids[idB]!);
        if (similarity > mergeThreshold) {
          // merge B into A: reassign all faces from B to A
          final facesOfB = await localMediaDb.loadFaceEmbeddingsByPersonId(idB);
          for (final face in facesOfB) {
            if (face.faceId != null) {
              await localMediaDb.updateFaceEmbeddingPersonId(face.faceId!, idA);
            }
          }
          await personStore.removePerson(idB);
          personStore.mergePersonInCache(idB, idA);
          personCentroids[idA] = FaceClustering.computeCentroid([personCentroids[idA]!, personCentroids[idB]!]);
          personCentroids.remove(idB);
          personIds.removeAt(j);
          j--;
        }
      }
    }
  }

  void updatePersons() {
    final updated = personStore.allPersonIds;
    if (!listEquals(updated, sortedPersonIds)) {
      sortedPersonIds = List.unmodifiable(updated);
      invalidatePersonFilterSummary();
      eventBus.fire(PersonsChangedEvent());
    }
  }

  // filter summary

  final Map<int, int> _personFilterEntryCountMap = {};
  final Map<int, int> _personFilterSizeMap = {};
  final Map<int, AvesEntry?> _personFilterRecentEntryMap = {};

  void invalidatePersonFilterSummary({Set<AvesEntry>? entries, bool notify = true}) {
    if (_personFilterEntryCountMap.isEmpty && _personFilterSizeMap.isEmpty && _personFilterRecentEntryMap.isEmpty) return;

    if (entries == null) {
      _personFilterEntryCountMap.clear();
      _personFilterSizeMap.clear();
      _personFilterRecentEntryMap.clear();
    } else {
      for (final entry in entries) {
        final personIds = personStore.getPersonsForEntry(entry.id);
        for (final personId in personIds) {
          _personFilterEntryCountMap.remove(personId);
          _personFilterSizeMap.remove(personId);
          _personFilterRecentEntryMap.remove(personId);
        }
      }
    }
    if (notify) {
      eventBus.fire(const PersonSummaryInvalidatedEvent());
    }
  }

  int personEntryCount(PersonFilter filter) {
    return _personFilterEntryCountMap.putIfAbsent(filter.personId, () => visibleEntries.where(filter.test).length);
  }

  int personSize(PersonFilter filter) {
    return _personFilterSizeMap.putIfAbsent(filter.personId, () => visibleEntries.where(filter.test).map((v) => v.sizeBytes ?? 0).sum);
  }

  AvesEntry? personRecentEntry(PersonFilter filter) {
    return _personFilterRecentEntryMap.putIfAbsent(filter.personId, () => sortedEntriesByDate.firstWhereOrNull(filter.test));
  }
}

class PersonsChangedEvent {}

class PersonSummaryInvalidatedEvent {
  const PersonSummaryInvalidatedEvent();
}

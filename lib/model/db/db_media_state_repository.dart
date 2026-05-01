import 'package:aves/model/db/db_repository_base.dart';
import 'package:aves/model/db/db_sqflite_schema.dart';
import 'package:aves/model/metadata/trash.dart';
import 'package:aves/model/viewer/video_playback.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

class MediaStateDbRepository extends DbRepositoryBase {
  static const _trashTable = SqfliteLocalMediaDbSchema.trashTable;
  static const _videoPlaybackTable = SqfliteLocalMediaDbSchema.videoPlaybackTable;
  static const _entryColorsTable = SqfliteLocalMediaDbSchema.entryColorsTable;
  static const _entryFacesTable = SqfliteLocalMediaDbSchema.entryFacesTable;

  MediaStateDbRepository(super.db);

  // trash

  Future<void> clearTrashDetails() async {
    final count = await db.delete(_trashTable, where: '1');
    debugPrint('$runtimeType clearTrashDetails deleted $count rows');
  }

  Future<Set<TrashDetails>> loadAllTrashDetails() async {
    final result = <TrashDetails>{};
    final cursor = await db.queryCursor(_trashTable, bufferSize: DbRepositoryBase.queryCursorBufferSize);
    while (await cursor.moveNext()) {
      result.add(TrashDetails.fromMap(cursor.current));
    }
    return result;
  }

  Future<void> updateTrash(int id, TrashDetails? details) async {
    final batch = db.batch();
    batch.delete(_trashTable, where: 'id = ?', whereArgs: [id]);
    _batchInsertTrashDetails(batch, details);
    await batch.commit(noResult: true);
  }

  void _batchInsertTrashDetails(Batch batch, TrashDetails? details) {
    if (details == null) return;
    batch.insert(
      _trashTable,
      details.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // video playback

  Future<void> clearVideoPlayback() async {
    final count = await db.delete(_videoPlaybackTable, where: '1');
    debugPrint('$runtimeType clearVideoPlayback deleted $count rows');
  }

  Future<Set<VideoPlaybackRow>> loadAllVideoPlayback() async {
    final result = <VideoPlaybackRow>{};
    final cursor = await db.queryCursor(_videoPlaybackTable, bufferSize: DbRepositoryBase.queryCursorBufferSize);
    while (await cursor.moveNext()) {
      final rowMap = cursor.current;
      final row = VideoPlaybackRow.fromMap(rowMap);
      if (row != null) {
        result.add(row);
      } else {
        debugPrint('$runtimeType failed to deserialize video playback from row=$rowMap');
      }
    }
    return result;
  }

  Future<VideoPlaybackRow?> loadVideoPlayback(int id) async {
    final rows = await db.query(_videoPlaybackTable, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;

    return VideoPlaybackRow.fromMap(rows.first);
  }

  Future<void> addVideoPlayback(Set<VideoPlaybackRow> rows) async {
    if (rows.isEmpty) return;

    final batch = db.batch();
    rows.forEach((row) => _batchInsertVideoPlayback(batch, row));
    await batch.commit(noResult: true);
  }

  void _batchInsertVideoPlayback(Batch batch, VideoPlaybackRow row) {
    batch.insert(
      _videoPlaybackTable,
      row.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeVideoPlayback(Set<int> ids) async {
    if (ids.isEmpty) return;

    final batch = db.batch();
    ids.forEach((id) => batch.delete(_videoPlaybackTable, where: 'id = ?', whereArgs: [id]));
    await batch.commit(noResult: true);
  }

  // entry colors

  Future<void> clearEntryColors() async {
    final count = await db.delete(_entryColorsTable, where: '1');
    debugPrint('$runtimeType clearEntryColors deleted $count rows');
  }

  Future<Map<int, List<int>>> loadAllEntryColors() async {
    final result = <int, List<int>>{};
    final cursor = await db.queryCursor(_entryColorsTable, bufferSize: DbRepositoryBase.queryCursorBufferSize);
    while (await cursor.moveNext()) {
      final row = cursor.current;
      final entryId = row['entryId'] as int;
      final colorValue = row['colorValue'] as int;
      result.putIfAbsent(entryId, () => []).add(colorValue);
    }
    return result;
  }

  Future<void> saveEntryColors(int entryId, List<int> colors) async {
    if (colors.isEmpty) return;
    final batch = db.batch();
    batch.delete(_entryColorsTable, where: 'entryId = ?', whereArgs: [entryId]);
    for (final color in colors) {
      batch.insert(
        _entryColorsTable,
        {'entryId': entryId, 'colorValue': color},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> removeEntryColorsByIds(Set<int> ids) async {
    if (ids.isEmpty) return;
    final batch = db.batch();
    ids.forEach((id) => batch.delete(_entryColorsTable, where: 'entryId = ?', whereArgs: [id]));
    await batch.commit(noResult: true);
  }

  // entry faces

  Future<void> clearEntryFaces() async {
    final count = await db.delete(_entryFacesTable, where: '1');
    debugPrint('$runtimeType clearEntryFaces deleted $count rows');
  }

  Future<Map<int, int>> loadAllEntryFaces() async {
    final result = <int, int>{};
    final cursor = await db.queryCursor(_entryFacesTable, bufferSize: DbRepositoryBase.queryCursorBufferSize);
    while (await cursor.moveNext()) {
      final row = cursor.current;
      final entryId = row['entryId'] as int;
      final faceCount = row['faceCount'] as int;
      result[entryId] = faceCount;
    }
    return result;
  }

  Future<void> saveEntryFaces(int entryId, int faceCount, String? boundingBoxes) async {
    await db.insert(
      _entryFacesTable,
      {
        'entryId': entryId,
        'faceCount': faceCount,
        'boundingBoxes': boundingBoxes,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeEntryFacesByIds(Set<int> ids) async {
    if (ids.isEmpty) return;
    final batch = db.batch();
    ids.forEach((id) => batch.delete(_entryFacesTable, where: 'entryId = ?', whereArgs: [id]));
    await batch.commit(noResult: true);
  }
}

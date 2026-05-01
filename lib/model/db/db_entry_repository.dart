import 'package:aves/model/db/db_repository_base.dart';
import 'package:aves/model/db/db_sqflite_schema.dart';
import 'package:aves/model/entry/entry.dart';
import 'package:aves/services/common/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

class EntryDbRepository extends DbRepositoryBase {
  static const _entryInsertSliceMaxCount = 10000;

  static const _entryTable = SqfliteLocalMediaDbSchema.entryTable;
  static const _dateTakenTable = SqfliteLocalMediaDbSchema.dateTakenTable;

  EntryDbRepository(super.db);

  Future<void> clearEntries() async {
    final count = await db.delete(_entryTable, where: '1');
    debugPrint('$runtimeType clearEntries deleted $count rows');
  }

  Future<Set<AvesEntry>> loadEntries({int? origin, String? directory}) async {
    String? where;
    final whereArgs = <Object?>[];

    if (origin != null) {
      where = 'origin = ?';
      whereArgs.add(origin);
    }

    final entries = <AvesEntry>{};
    if (directory != null) {
      final separator = pContext.separator;
      if (!directory.endsWith(separator)) {
        directory = '$directory$separator';
      }

      where = '${where != null ? '$where AND ' : ''}path LIKE ?';
      whereArgs.add('$directory%');
      final cursor = await db.queryCursor(_entryTable, where: where, whereArgs: whereArgs, bufferSize: DbRepositoryBase.queryCursorBufferSize);

      final dirLength = directory.length;
      while (await cursor.moveNext()) {
        final row = cursor.current;
        final path = row['path'] as String?;
        if (path != null && !path.substring(dirLength).contains(separator)) {
          entries.add(AvesEntry.fromMap(row));
        }
      }
    } else {
      final cursor = await db.queryCursor(_entryTable, where: where, whereArgs: whereArgs, bufferSize: DbRepositoryBase.queryCursorBufferSize);
      while (await cursor.moveNext()) {
        entries.add(AvesEntry.fromMap(cursor.current));
      }
    }

    return entries;
  }

  Future<Set<AvesEntry>> loadEntriesById(Set<int> ids) => getByIds(ids, _entryTable, AvesEntry.fromMap);

  Future<void> insertEntries(Set<AvesEntry> entries) async {
    if (entries.isEmpty) return;
    final stopwatch = Stopwatch()..start();
    int inserted = 0;
    await Future.forEach(entries.slices(_entryInsertSliceMaxCount), (slice) async {
      debugPrint('$runtimeType saveEntries inserting slice of [${inserted + 1}, ${inserted + slice.length}] entries');
      final batch = db.batch();
      slice.forEach((entry) => _batchInsertEntry(batch, entry));
      await batch.commit(noResult: true);
      inserted += slice.length;
    });
    debugPrint('$runtimeType saveEntries complete in ${stopwatch.elapsed.inMilliseconds}ms for ${entries.length} entries');
  }

  Future<void> updateEntry(int id, AvesEntry entry) async {
    final batch = db.batch();
    batch.delete(_entryTable, where: 'id = ?', whereArgs: [id]);
    _batchInsertEntry(batch, entry);
    await batch.commit(noResult: true);
  }

  void _batchInsertEntry(Batch batch, AvesEntry entry) {
    batch.insert(
      _entryTable,
      entry.toDatabaseMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Set<AvesEntry>> searchLiveEntries(String query, {int? limit}) async {
    final rows = await db.query(
      _entryTable,
      where: '(title LIKE ? OR path LIKE ?) AND trashed = ?',
      whereArgs: ['%$query%', '%$query%', 0],
      orderBy: 'sourceDateTakenMillis DESC',
      limit: limit,
    );
    return rows.map(AvesEntry.fromMap).toSet();
  }

  Future<Set<AvesEntry>> searchLiveDuplicates(int origin, Set<AvesEntry>? entries) async {
    String where = 'origin = ? AND trashed = ?';
    if (entries != null) {
      where += ' AND contentId IN (${entries.map((v) => v.contentId).join(',')})';
    }
    final rows = await db.rawQuery(
      'SELECT *, MAX(id) AS id'
      ' FROM $_entryTable'
      ' WHERE $where'
      ' GROUP BY contentId'
      ' HAVING COUNT(id) > 1',
      [origin, 0],
    );
    final duplicates = rows.map(AvesEntry.fromMap).toSet();
    if (duplicates.isNotEmpty) {
      debugPrint('$runtimeType found duplicates=$duplicates');
    }
    return duplicates;
  }

  // date taken

  Future<void> clearDates() async {
    final count = await db.delete(_dateTakenTable, where: '1');
    debugPrint('$runtimeType clearDates deleted $count rows');
  }

  Future<Map<int?, int?>> loadDates() async {
    final result = <int?, int?>{};
    final cursor = await db.queryCursor(_dateTakenTable, bufferSize: DbRepositoryBase.queryCursorBufferSize);
    while (await cursor.moveNext()) {
      final row = cursor.current;
      result[row['id'] as int] = row['dateMillis'] as int? ?? 0;
    }
    return result;
  }
}

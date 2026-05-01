import 'package:aves/model/covers.dart';
import 'package:aves/model/db/db_repository_base.dart';
import 'package:aves/model/db/db_sqflite_schema.dart';
import 'package:aves/model/dynamic_albums.dart';
import 'package:aves/model/favourites.dart';
import 'package:aves/model/filters/filters.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

class CollectionDbRepository extends DbRepositoryBase {
  static const _favouriteTable = SqfliteLocalMediaDbSchema.favouriteTable;
  static const _coverTable = SqfliteLocalMediaDbSchema.coverTable;
  static const _dynamicAlbumTable = SqfliteLocalMediaDbSchema.dynamicAlbumTable;

  CollectionDbRepository(super.db);

  // favourites

  Future<void> clearFavourites() async {
    final count = await db.delete(_favouriteTable, where: '1');
    debugPrint('$runtimeType clearFavourites deleted $count rows');
  }

  Future<Set<FavouriteRow>> loadAllFavourites() async {
    final result = <FavouriteRow>{};
    final cursor = await db.queryCursor(_favouriteTable, bufferSize: DbRepositoryBase.queryCursorBufferSize);
    while (await cursor.moveNext()) {
      result.add(FavouriteRow.fromMap(cursor.current));
    }
    return result;
  }

  Future<void> addFavourites(Set<FavouriteRow> rows) async {
    if (rows.isEmpty) return;
    final batch = db.batch();
    rows.forEach((row) => _batchInsertFavourite(batch, row));
    await batch.commit(noResult: true);
  }

  Future<void> updateFavouriteId(int id, FavouriteRow row) async {
    final batch = db.batch();
    batch.delete(_favouriteTable, where: 'id = ?', whereArgs: [id]);
    _batchInsertFavourite(batch, row);
    await batch.commit(noResult: true);
  }

  void _batchInsertFavourite(Batch batch, FavouriteRow row) {
    batch.insert(
      _favouriteTable,
      row.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeFavourites(Set<FavouriteRow> rows) async {
    if (rows.isEmpty) return;
    final ids = rows.map((row) => row.entryId);
    if (ids.isEmpty) return;

    final batch = db.batch();
    ids.forEach((id) => batch.delete(_favouriteTable, where: 'id = ?', whereArgs: [id]));
    await batch.commit(noResult: true);
  }

  // covers

  Future<void> clearCovers() async {
    final count = await db.delete(_coverTable, where: '1');
    debugPrint('$runtimeType clearCovers deleted $count rows');
  }

  Future<Set<CoverRow>> loadAllCovers() async {
    final result = <CoverRow>{};
    final cursor = await db.queryCursor(_coverTable, bufferSize: DbRepositoryBase.queryCursorBufferSize);
    while (await cursor.moveNext()) {
      final rowMap = cursor.current;
      final row = CoverRow.fromMap(rowMap);
      if (row != null) {
        result.add(row);
      } else {
        debugPrint('$runtimeType failed to deserialize cover from row=$rowMap');
      }
    }
    return result;
  }

  Future<void> addCovers(Set<CoverRow> rows) async {
    if (rows.isEmpty) return;

    final batch = db.batch();
    rows.forEach((row) => _batchInsertCover(batch, row));
    await batch.commit(noResult: true);
  }

  Future<void> updateCoverEntryId(int id, CoverRow row) async {
    final batch = db.batch();
    batch.delete(_coverTable, where: 'entryId = ?', whereArgs: [id]);
    _batchInsertCover(batch, row);
    await batch.commit(noResult: true);
  }

  void _batchInsertCover(Batch batch, CoverRow row) {
    batch.insert(
      _coverTable,
      row.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeCovers(Set<CollectionFilter> filters) async {
    if (filters.isEmpty) return;

    final obsoleteFilterJson = <String>{};

    final rows = await db.query(_coverTable);
    rows.forEach((row) {
      final filterJson = row['filter'] as String?;
      if (filterJson != null) {
        final filter = CollectionFilter.fromJson(filterJson);
        if (filters.any((v) => filter == v)) {
          obsoleteFilterJson.add(filterJson);
        }
      }
    });

    final batch = db.batch();
    obsoleteFilterJson.forEach((filterJson) => batch.delete(_coverTable, where: 'filter = ?', whereArgs: [filterJson]));
    await batch.commit(noResult: true);
  }

  // dynamic albums

  Future<int> clearDynamicAlbums() async {
    final count = await db.delete(_dynamicAlbumTable, where: '1');
    debugPrint('$runtimeType clearDynamicAlbums deleted $count rows');
    return count;
  }

  Future<Set<DynamicAlbumRow>> loadAllDynamicAlbums({int bufferSize = DbRepositoryBase.queryCursorBufferSize}) async {
    final result = <DynamicAlbumRow>{};
    try {
      final cursor = await db.queryCursor(_dynamicAlbumTable, bufferSize: bufferSize);
      while (await cursor.moveNext()) {
        final rowMap = cursor.current;
        final row = DynamicAlbumRow.fromMap(rowMap);
        if (row != null) {
          result.add(row);
        } else {
          debugPrint('$runtimeType failed to deserialize dynamic album from row=$rowMap');
        }
      }
    } catch (error, stack) {
      debugPrint('$runtimeType failed to query table=$_dynamicAlbumTable error=$error\n$stack');
      if (bufferSize > 1) {
        debugPrint('$runtimeType retry to query table=$_dynamicAlbumTable with no cursor buffer');
        final safeRows = await loadAllDynamicAlbums(bufferSize: 1);
        final clearedCount = await clearDynamicAlbums();
        await addDynamicAlbums(safeRows);
        final addedCount = safeRows.length;
        final lostCount = clearedCount - addedCount;
        debugPrint('$runtimeType kept $addedCount rows, lost $lostCount rows from table=$_dynamicAlbumTable');
        return safeRows;
      }
    }
    return result;
  }

  Future<void> addDynamicAlbums(Set<DynamicAlbumRow> rows) async {
    if (rows.isEmpty) return;

    final batch = db.batch();
    rows.forEach((row) => _batchInsertDynamicAlbum(batch, row));
    await batch.commit(noResult: true);
  }

  void _batchInsertDynamicAlbum(Batch batch, DynamicAlbumRow row) {
    batch.insert(
      _dynamicAlbumTable,
      row.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeDynamicAlbums(Set<String> names) async {
    if (names.isEmpty) return;

    final batch = db.batch();
    names.forEach((name) => batch.delete(_dynamicAlbumTable, where: 'name = ?', whereArgs: [name]));
    await batch.commit(noResult: true);
  }
}

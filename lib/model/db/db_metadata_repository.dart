import 'package:aves/model/db/db_repository_base.dart';
import 'package:aves/model/db/db_sqflite_schema.dart';
import 'package:aves/model/metadata/catalog.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

class MetadataDbRepository extends DbRepositoryBase {
  static const _metadataTable = SqfliteLocalMediaDbSchema.metadataTable;
  static const _dateTakenTable = SqfliteLocalMediaDbSchema.dateTakenTable;

  MetadataDbRepository(super.db);

  Future<void> clearCatalogMetadata() async {
    final count = await db.delete(_metadataTable, where: '1');
    debugPrint('$runtimeType clearMetadataEntries deleted $count rows');
  }

  Future<Set<CatalogMetadata>> loadCatalogMetadata() async {
    final result = <CatalogMetadata>{};
    final cursor = await db.queryCursor(_metadataTable, bufferSize: DbRepositoryBase.queryCursorBufferSize);
    while (await cursor.moveNext()) {
      result.add(CatalogMetadata.fromMap(cursor.current));
    }
    return result;
  }

  Future<Set<CatalogMetadata>> loadCatalogMetadataById(Set<int> ids) => getByIds(ids, _metadataTable, CatalogMetadata.fromMap);

  Future<void> saveCatalogMetadata(Set<CatalogMetadata> metadataEntries) async {
    if (metadataEntries.isEmpty) return;
    final stopwatch = Stopwatch()..start();
    try {
      final batch = db.batch();
      metadataEntries.forEach((metadata) => _batchInsertMetadata(batch, metadata));
      await batch.commit(noResult: true);
      debugPrint('$runtimeType saveMetadata complete in ${stopwatch.elapsed.inMilliseconds}ms for ${metadataEntries.length} entries');
    } catch (error, stack) {
      debugPrint('$runtimeType failed to save metadata with error=$error\n$stack');
    }
  }

  Future<void> updateCatalogMetadata(int id, CatalogMetadata? metadata) async {
    final batch = db.batch();
    batch.delete(_dateTakenTable, where: 'id = ?', whereArgs: [id]);
    batch.delete(_metadataTable, where: 'id = ?', whereArgs: [id]);
    _batchInsertMetadata(batch, metadata);
    await batch.commit(noResult: true);
  }

  void _batchInsertMetadata(Batch batch, CatalogMetadata? metadata) {
    if (metadata == null) return;
    if (metadata.dateMillis != 0) {
      batch.insert(
        _dateTakenTable,
        {
          'id': metadata.id,
          'dateMillis': metadata.dateMillis,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    batch.insert(
      _metadataTable,
      metadata.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

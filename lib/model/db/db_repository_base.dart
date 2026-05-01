import 'package:sqflite/sqflite.dart';

abstract class DbRepositoryBase {
  final Database db;

  static const queryCursorBufferSize = 1000;

  DbRepositoryBase(this.db);

  Future<Set<T>> getByIds<T>(Set<int> ids, String table, T Function(Map<String, Object?> row) mapRow) async {
    final result = <T>{};
    if (ids.isNotEmpty) {
      final cursor = await db.queryCursor(table, where: 'id IN (${ids.join(',')})', bufferSize: queryCursorBufferSize);
      while (await cursor.moveNext()) {
        result.add(mapRow(cursor.current));
      }
    }
    return result;
  }
}

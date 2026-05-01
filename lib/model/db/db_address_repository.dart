import 'package:aves/model/db/db_repository_base.dart';
import 'package:aves/model/db/db_sqflite_schema.dart';
import 'package:aves/model/metadata/address.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

class AddressDbRepository extends DbRepositoryBase {
  static const _addressTable = SqfliteLocalMediaDbSchema.addressTable;

  AddressDbRepository(super.db);

  Future<void> clearAddresses() async {
    final count = await db.delete(_addressTable, where: '1');
    debugPrint('$runtimeType clearAddresses deleted $count rows');
  }

  Future<Set<AddressDetails>> loadAddresses() async {
    final result = <AddressDetails>{};
    final cursor = await db.queryCursor(_addressTable, bufferSize: DbRepositoryBase.queryCursorBufferSize);
    while (await cursor.moveNext()) {
      result.add(AddressDetails.fromMap(cursor.current));
    }
    return result;
  }

  Future<Set<AddressDetails>> loadAddressesById(Set<int> ids) => getByIds(ids, _addressTable, AddressDetails.fromMap);

  Future<void> saveAddresses(Set<AddressDetails> addresses) async {
    if (addresses.isEmpty) return;
    final stopwatch = Stopwatch()..start();
    final batch = db.batch();
    addresses.forEach((address) => _batchInsertAddress(batch, address));
    await batch.commit(noResult: true);
    debugPrint('$runtimeType saveAddresses complete in ${stopwatch.elapsed.inMilliseconds}ms for ${addresses.length} entries');
  }

  Future<void> updateAddress(int id, AddressDetails? address) async {
    final batch = db.batch();
    batch.delete(_addressTable, where: 'id = ?', whereArgs: [id]);
    _batchInsertAddress(batch, address);
    await batch.commit(noResult: true);
  }

  void _batchInsertAddress(Batch batch, AddressDetails? address) {
    if (address == null) return;
    batch.insert(
      _addressTable,
      address.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

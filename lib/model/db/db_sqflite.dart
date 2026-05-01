import 'dart:io';

import 'package:aves/model/covers.dart';
import 'package:aves/model/db/db.dart';
import 'package:aves/model/db/db_address_repository.dart';
import 'package:aves/model/db/db_collection_repository.dart';
import 'package:aves/model/db/db_entry_repository.dart';
import 'package:aves/model/db/db_media_state_repository.dart';
import 'package:aves/model/db/db_metadata_repository.dart';
import 'package:aves/model/db/db_sqflite_schema.dart';
import 'package:aves/model/db/db_sqflite_upgrade.dart';
import 'package:aves/model/dynamic_albums.dart';
import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/favourites.dart';
import 'package:aves/model/filters/filters.dart';
import 'package:aves/model/metadata/address.dart';
import 'package:aves/model/metadata/catalog.dart';
import 'package:aves/model/metadata/trash.dart';
import 'package:aves/model/viewer/video_playback.dart';
import 'package:aves/services/common/services.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

class SqfliteLocalMediaDb implements LocalMediaDb {
  late Database _db;
  late EntryDbRepository _entries;
  late MetadataDbRepository _metadata;
  late AddressDbRepository _addresses;
  late CollectionDbRepository _collections;
  late MediaStateDbRepository _mediaState;

  @override
  Future<String> get path async => pContext.join(await getDatabasesPath(), 'metadata.db');

  static const entryTable = SqfliteLocalMediaDbSchema.entryTable;
  static const dateTakenTable = SqfliteLocalMediaDbSchema.dateTakenTable;
  static const metadataTable = SqfliteLocalMediaDbSchema.metadataTable;
  static const addressTable = SqfliteLocalMediaDbSchema.addressTable;
  static const favouriteTable = SqfliteLocalMediaDbSchema.favouriteTable;
  static const coverTable = SqfliteLocalMediaDbSchema.coverTable;
  static const dynamicAlbumTable = SqfliteLocalMediaDbSchema.dynamicAlbumTable;
  static const trashTable = SqfliteLocalMediaDbSchema.trashTable;
  static const videoPlaybackTable = SqfliteLocalMediaDbSchema.videoPlaybackTable;
  static const entryColorsTable = SqfliteLocalMediaDbSchema.entryColorsTable;
  static const entryFacesTable = SqfliteLocalMediaDbSchema.entryFacesTable;

  static int _lastId = 0;

  @override
  int get nextId => ++_lastId;

  @override
  Future<void> init() async {
    _db = await openDatabase(
      await path,
      onCreate: (db, version) => SqfliteLocalMediaDbSchema.createLatestVersion(db),
      onUpgrade: LocalMediaDbUpgrader.upgradeDb,
      version: 23,
    );

    _entries = EntryDbRepository(_db);
    _metadata = MetadataDbRepository(_db);
    _addresses = AddressDbRepository(_db);
    _collections = CollectionDbRepository(_db);
    _mediaState = MediaStateDbRepository(_db);

    final maxIdRows = await _db.rawQuery('SELECT MAX(id) AS maxId FROM $entryTable');
    _lastId = (maxIdRows.firstOrNull?['maxId'] as int?) ?? 0;
  }

  @override
  Future<int> dbFileSize() async {
    final file = File(await path);
    return await file.exists() ? await file.length() : 0;
  }

  @override
  Future<void> reset() async {
    debugPrint('$runtimeType reset');
    await _db.close();
    await deleteDatabase(await path);
    await init();
  }

  @override
  Future<void> removeIds(Set<int> ids, {Set<EntryDataType>? dataTypes}) async {
    if (ids.isEmpty) return;

    final _dataTypes = dataTypes ?? EntryDataType.values.toSet();

    final batch = _db.batch();
    const where = 'id = ?';
    const coverWhere = 'entryId = ?';
    ids.forEach((id) {
      final whereArgs = [id];
      if (_dataTypes.contains(EntryDataType.basic)) {
        batch.delete(entryTable, where: where, whereArgs: whereArgs);
      }
      if (_dataTypes.contains(EntryDataType.catalog)) {
        batch.delete(dateTakenTable, where: where, whereArgs: whereArgs);
        batch.delete(metadataTable, where: where, whereArgs: whereArgs);
      }
      if (_dataTypes.contains(EntryDataType.address)) {
        batch.delete(addressTable, where: where, whereArgs: whereArgs);
      }
      if (_dataTypes.contains(EntryDataType.references)) {
        batch.delete(favouriteTable, where: where, whereArgs: whereArgs);
        batch.delete(coverTable, where: coverWhere, whereArgs: whereArgs);
        batch.delete(trashTable, where: where, whereArgs: whereArgs);
        batch.delete(videoPlaybackTable, where: where, whereArgs: whereArgs);
        batch.delete(entryColorsTable, where: 'entryId = ?', whereArgs: whereArgs);
        batch.delete(entryFacesTable, where: 'entryId = ?', whereArgs: whereArgs);
      }
    });
    await batch.commit(noResult: true);
  }

  // entries

  @override
  Future<void> clearEntries() => _entries.clearEntries();

  @override
  Future<Set<AvesEntry>> loadEntries({int? origin, String? directory}) => _entries.loadEntries(origin: origin, directory: directory);

  @override
  Future<Set<AvesEntry>> loadEntriesById(Set<int> ids) => _entries.loadEntriesById(ids);

  @override
  Future<void> insertEntries(Set<AvesEntry> entries) => _entries.insertEntries(entries);

  @override
  Future<void> updateEntry(int id, AvesEntry entry) => _entries.updateEntry(id, entry);

  @override
  Future<Set<AvesEntry>> searchLiveEntries(String query, {int? limit}) => _entries.searchLiveEntries(query, limit: limit);

  @override
  Future<Set<AvesEntry>> searchLiveDuplicates(int origin, Set<AvesEntry>? entries) => _entries.searchLiveDuplicates(origin, entries);

  // date taken

  @override
  Future<void> clearDates() => _entries.clearDates();

  @override
  Future<Map<int?, int?>> loadDates() => _entries.loadDates();

  // catalog metadata

  @override
  Future<void> clearCatalogMetadata() => _metadata.clearCatalogMetadata();

  @override
  Future<Set<CatalogMetadata>> loadCatalogMetadata() => _metadata.loadCatalogMetadata();

  @override
  Future<Set<CatalogMetadata>> loadCatalogMetadataById(Set<int> ids) => _metadata.loadCatalogMetadataById(ids);

  @override
  Future<void> saveCatalogMetadata(Set<CatalogMetadata> metadataEntries) => _metadata.saveCatalogMetadata(metadataEntries);

  @override
  Future<void> updateCatalogMetadata(int id, CatalogMetadata? metadata) => _metadata.updateCatalogMetadata(id, metadata);

  // address

  @override
  Future<void> clearAddresses() => _addresses.clearAddresses();

  @override
  Future<Set<AddressDetails>> loadAddresses() => _addresses.loadAddresses();

  @override
  Future<Set<AddressDetails>> loadAddressesById(Set<int> ids) => _addresses.loadAddressesById(ids);

  @override
  Future<void> saveAddresses(Set<AddressDetails> addresses) => _addresses.saveAddresses(addresses);

  @override
  Future<void> updateAddress(int id, AddressDetails? address) => _addresses.updateAddress(id, address);

  // trash

  @override
  Future<void> clearTrashDetails() => _mediaState.clearTrashDetails();

  @override
  Future<Set<TrashDetails>> loadAllTrashDetails() => _mediaState.loadAllTrashDetails();

  @override
  Future<void> updateTrash(int id, TrashDetails? details) => _mediaState.updateTrash(id, details);

  // favourites

  @override
  Future<void> clearFavourites() => _collections.clearFavourites();

  @override
  Future<Set<FavouriteRow>> loadAllFavourites() => _collections.loadAllFavourites();

  @override
  Future<void> addFavourites(Set<FavouriteRow> rows) => _collections.addFavourites(rows);

  @override
  Future<void> updateFavouriteId(int id, FavouriteRow row) => _collections.updateFavouriteId(id, row);

  @override
  Future<void> removeFavourites(Set<FavouriteRow> rows) => _collections.removeFavourites(rows);

  // covers

  @override
  Future<void> clearCovers() => _collections.clearCovers();

  @override
  Future<Set<CoverRow>> loadAllCovers() => _collections.loadAllCovers();

  @override
  Future<void> addCovers(Set<CoverRow> rows) => _collections.addCovers(rows);

  @override
  Future<void> updateCoverEntryId(int id, CoverRow row) => _collections.updateCoverEntryId(id, row);

  @override
  Future<void> removeCovers(Set<CollectionFilter> filters) => _collections.removeCovers(filters);

  // dynamic albums

  @override
  Future<int> clearDynamicAlbums() => _collections.clearDynamicAlbums();

  @override
  Future<Set<DynamicAlbumRow>> loadAllDynamicAlbums() => _collections.loadAllDynamicAlbums();

  @override
  Future<void> addDynamicAlbums(Set<DynamicAlbumRow> rows) => _collections.addDynamicAlbums(rows);

  @override
  Future<void> removeDynamicAlbums(Set<String> names) => _collections.removeDynamicAlbums(names);

  // entry colors

  @override
  Future<void> clearEntryColors() => _mediaState.clearEntryColors();

  @override
  Future<Map<int, List<int>>> loadAllEntryColors() => _mediaState.loadAllEntryColors();

  @override
  Future<void> saveEntryColors(int entryId, List<int> colors) => _mediaState.saveEntryColors(entryId, colors);

  @override
  Future<void> removeEntryColorsByIds(Set<int> ids) => _mediaState.removeEntryColorsByIds(ids);

  // entry faces

  @override
  Future<void> clearEntryFaces() => _mediaState.clearEntryFaces();

  @override
  Future<Map<int, int>> loadAllEntryFaces() => _mediaState.loadAllEntryFaces();

  @override
  Future<void> saveEntryFaces(int entryId, int faceCount, String? boundingBoxes) => _mediaState.saveEntryFaces(entryId, faceCount, boundingBoxes);

  @override
  Future<void> removeEntryFacesByIds(Set<int> ids) => _mediaState.removeEntryFacesByIds(ids);

  // video playback

  @override
  Future<void> clearVideoPlayback() => _mediaState.clearVideoPlayback();

  @override
  Future<Set<VideoPlaybackRow>> loadAllVideoPlayback() => _mediaState.loadAllVideoPlayback();

  @override
  Future<VideoPlaybackRow?> loadVideoPlayback(int id) => _mediaState.loadVideoPlayback(id);

  @override
  Future<void> addVideoPlayback(Set<VideoPlaybackRow> rows) => _mediaState.addVideoPlayback(rows);

  @override
  Future<void> removeVideoPlayback(Set<int> ids) => _mediaState.removeVideoPlayback(ids);
}

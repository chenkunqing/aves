import 'package:aves/model/covers.dart';
import 'package:aves/model/dynamic_albums.dart';
import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/face_embedding.dart';
import 'package:aves/model/favourites.dart';
import 'package:aves/model/filters/filters.dart';
import 'package:aves/model/metadata/address.dart';
import 'package:aves/model/metadata/catalog.dart';
import 'package:aves/model/metadata/trash.dart';
import 'package:aves/model/person.dart';
import 'package:aves/model/vaults/details.dart';
import 'package:aves/model/viewer/video_playback.dart';

abstract class LocalMediaDb {
  int get nextId;

  Future<String> get path;

  Future<void> init();

  Future<int> dbFileSize();

  Future<void> reset();

  Future<void> removeIds(Set<int> ids, {Set<EntryDataType>? dataTypes});

  // entries

  Future<void> clearEntries();

  Future<Set<AvesEntry>> loadEntries({int? origin, String? directory});

  Future<Set<AvesEntry>> loadEntriesById(Set<int> ids);

  Future<void> insertEntries(Set<AvesEntry> entries);

  Future<void> updateEntry(int id, AvesEntry entry);

  Future<Set<AvesEntry>> searchLiveEntries(String query, {int? limit});

  Future<Set<AvesEntry>> searchLiveDuplicates(int origin, Set<AvesEntry>? entries);

  // date taken

  Future<void> clearDates();

  Future<Map<int?, int?>> loadDates();

  // catalog metadata

  Future<void> clearCatalogMetadata();

  Future<Set<CatalogMetadata>> loadCatalogMetadata();

  Future<Set<CatalogMetadata>> loadCatalogMetadataById(Set<int> ids);

  Future<void> saveCatalogMetadata(Set<CatalogMetadata> metadataEntries);

  Future<void> updateCatalogMetadata(int id, CatalogMetadata? metadata);

  // address

  Future<void> clearAddresses();

  Future<Set<AddressDetails>> loadAddresses();

  Future<Set<AddressDetails>> loadAddressesById(Set<int> ids);

  Future<void> saveAddresses(Set<AddressDetails> addresses);

  Future<void> updateAddress(int id, AddressDetails? address);

  // vaults

  Future<void> clearVaults();

  Future<Set<VaultDetails>> loadAllVaults();

  Future<void> addVaults(Set<VaultDetails> rows);

  Future<void> updateVault(String oldName, VaultDetails row);

  Future<void> removeVaults(Set<VaultDetails> rows);

  // trash

  Future<void> clearTrashDetails();

  Future<Set<TrashDetails>> loadAllTrashDetails();

  Future<void> updateTrash(int id, TrashDetails? details);

  // favourites

  Future<void> clearFavourites();

  Future<Set<FavouriteRow>> loadAllFavourites();

  Future<void> addFavourites(Set<FavouriteRow> rows);

  Future<void> updateFavouriteId(int id, FavouriteRow row);

  Future<void> removeFavourites(Set<FavouriteRow> rows);

  // covers

  Future<void> clearCovers();

  Future<Set<CoverRow>> loadAllCovers();

  Future<void> addCovers(Set<CoverRow> rows);

  Future<void> updateCoverEntryId(int id, CoverRow row);

  Future<void> removeCovers(Set<CollectionFilter> filters);

  // dynamic albums

  Future<int> clearDynamicAlbums();

  Future<Set<DynamicAlbumRow>> loadAllDynamicAlbums();

  Future<void> addDynamicAlbums(Set<DynamicAlbumRow> rows);

  Future<void> removeDynamicAlbums(Set<String> names);

  // entry colors

  Future<void> clearEntryColors();

  Future<Map<int, List<int>>> loadAllEntryColors();

  Future<void> saveEntryColors(int entryId, List<int> colors);

  Future<void> removeEntryColorsByIds(Set<int> ids);

  // entry faces

  Future<void> clearEntryFaces();

  Future<Map<int, int>> loadAllEntryFaces();

  Future<void> saveEntryFaces(int entryId, int faceCount, String? boundingBoxes);

  Future<void> removeEntryFacesByIds(Set<int> ids);

  Future<Map<int, String>> loadEntryFacesNeedingEmbeddings(String modelVersion);

  // face embeddings

  Future<void> clearFaceEmbeddings();

  Future<Map<int, List<FaceEmbeddingRow>>> loadAllFaceEmbeddings();

  Future<void> saveFaceEmbeddings(int entryId, List<FaceEmbeddingRow> embeddings);

  Future<void> removeFaceEmbeddingsByEntryIds(Set<int> ids);

  Future<void> updateFaceEmbeddingPersonId(int faceId, int? personId);

  Future<List<FaceEmbeddingRow>> loadFaceEmbeddingsByPersonId(int personId);

  Future<List<FaceEmbeddingRow>> loadUnassignedFaceEmbeddings();

  Future<void> resetAllFaceEmbeddingPersonIds();

  // persons

  Future<void> clearPersons();

  Future<Set<PersonRow>> loadAllPersons();

  Future<int> savePerson(PersonRow person);

  Future<void> updatePerson(PersonRow person);

  Future<void> removePerson(int personId);

  // video playback

  Future<void> clearVideoPlayback();

  Future<Set<VideoPlaybackRow>> loadAllVideoPlayback();

  Future<VideoPlaybackRow?> loadVideoPlayback(int id);

  Future<void> addVideoPlayback(Set<VideoPlaybackRow> rows);

  Future<void> removeVideoPlayback(Set<int> ids);
}

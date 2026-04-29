import 'package:sqflite/sqflite.dart';

class SqfliteLocalMediaDbSchema {
  static const entryTable = 'entry';
  static const dateTakenTable = 'dateTaken';
  static const metadataTable = 'metadata';
  static const addressTable = 'address';
  static const favouriteTable = 'favourites';
  static const coverTable = 'covers';
  static const dynamicAlbumTable = 'dynamicAlbums';
  static const vaultTable = 'vaults';
  static const trashTable = 'trash';
  static const videoPlaybackTable = 'videoPlayback';
  static const entryColorsTable = 'entryColors';
  static const entryFacesTable = 'entryFaces';
  static const faceEmbeddingsTable = 'faceEmbeddings';
  static const personsTable = 'persons';

  static const allTables = [
    entryTable,
    dateTakenTable,
    metadataTable,
    addressTable,
    favouriteTable,
    coverTable,
    dynamicAlbumTable,
    vaultTable,
    trashTable,
    videoPlaybackTable,
    entryColorsTable,
    entryFacesTable,
    faceEmbeddingsTable,
    personsTable,
  ];

  static Future<void> createLatestVersion(Database db) async {
    await Future.forEach(allTables, (table) => createTable(db, table));
  }

  static Future<void> createTable(Database db, String table) {
    switch (table) {
      case entryTable:
        return db.execute(
          'CREATE TABLE $entryTable('
          'id INTEGER PRIMARY KEY'
          ', contentId INTEGER'
          ', uri TEXT'
          ', path TEXT'
          ', sourceMimeType TEXT'
          ', width INTEGER'
          ', height INTEGER'
          ', sourceRotationDegrees INTEGER'
          ', sizeBytes INTEGER'
          ', title TEXT'
          ', dateAddedSecs INTEGER DEFAULT (strftime(\'%s\',\'now\'))'
          ', dateModifiedMillis INTEGER'
          ', sourceDateTakenMillis INTEGER'
          ', durationMillis INTEGER'
          ', trashed INTEGER DEFAULT 0'
          ', origin INTEGER DEFAULT 0'
          ')',
        );
      case dateTakenTable:
        return db.execute(
          'CREATE TABLE $dateTakenTable('
          'id INTEGER PRIMARY KEY'
          ', dateMillis INTEGER'
          ')',
        );
      case metadataTable:
        return db.execute(
          'CREATE TABLE $metadataTable('
          'id INTEGER PRIMARY KEY'
          ', mimeType TEXT'
          ', dateMillis INTEGER'
          ', flags INTEGER'
          ', rotationDegrees INTEGER'
          ', xmpSubjects TEXT'
          ', xmpTitle TEXT'
          ', latitude REAL'
          ', longitude REAL'
          ', rating INTEGER'
          ')',
        );
      case addressTable:
        return db.execute(
          'CREATE TABLE $addressTable('
          'id INTEGER PRIMARY KEY'
          ', addressLine TEXT'
          ', countryCode TEXT'
          ', countryName TEXT'
          ', adminArea TEXT'
          ', locality TEXT'
          ')',
        );
      case favouriteTable:
        return db.execute(
          'CREATE TABLE $favouriteTable('
          'id INTEGER PRIMARY KEY'
          ')',
        );
      case coverTable:
        return db.execute(
          'CREATE TABLE $coverTable('
          'filter TEXT PRIMARY KEY'
          ', entryId INTEGER'
          ', packageName TEXT'
          ', color TEXT'
          ')',
        );
      case dynamicAlbumTable:
        return db.execute(
          'CREATE TABLE $dynamicAlbumTable('
          'name TEXT PRIMARY KEY'
          ', filter TEXT'
          ')',
        );
      case vaultTable:
        return db.execute(
          'CREATE TABLE $vaultTable('
          'name TEXT PRIMARY KEY'
          ', autoLock INTEGER'
          ', useBin INTEGER'
          ', lockType TEXT'
          ')',
        );
      case trashTable:
        return db.execute(
          'CREATE TABLE $trashTable('
          'id INTEGER PRIMARY KEY'
          ', path TEXT'
          ', dateMillis INTEGER'
          ')',
        );
      case videoPlaybackTable:
        return db.execute(
          'CREATE TABLE $videoPlaybackTable('
          'id INTEGER PRIMARY KEY'
          ', resumeTimeMillis INTEGER'
          ')',
        );
      case entryColorsTable:
        return db.execute(
          'CREATE TABLE $entryColorsTable('
          'entryId INTEGER'
          ', colorValue INTEGER'
          ', PRIMARY KEY (entryId, colorValue)'
          ')',
        );
      case entryFacesTable:
        return db.execute(
          'CREATE TABLE $entryFacesTable('
          'entryId INTEGER PRIMARY KEY'
          ', faceCount INTEGER'
          ', boundingBoxes TEXT'
          ')',
        );
      case faceEmbeddingsTable:
        return db
            .execute(
              'CREATE TABLE $faceEmbeddingsTable('
              'faceId INTEGER PRIMARY KEY AUTOINCREMENT'
              ', entryId INTEGER NOT NULL'
              ', boundingBox TEXT NOT NULL'
              ', embedding BLOB NOT NULL'
              ', modelVersion TEXT NOT NULL'
              ', personId INTEGER'
              ')',
            )
            .then((_) async {
              await db.execute('CREATE INDEX IF NOT EXISTS idx_faceEmbeddings_entryId ON $faceEmbeddingsTable(entryId)');
              await db.execute('CREATE INDEX IF NOT EXISTS idx_faceEmbeddings_entryId_modelVersion ON $faceEmbeddingsTable(entryId, modelVersion)');
              await db.execute('CREATE INDEX IF NOT EXISTS idx_faceEmbeddings_personId ON $faceEmbeddingsTable(personId)');
            });
      case personsTable:
        return db.execute(
          'CREATE TABLE $personsTable('
          'personId INTEGER PRIMARY KEY AUTOINCREMENT'
          ', name TEXT'
          ', coverEntryId INTEGER'
          ')',
        );
      default:
        throw Exception('unknown table=$table');
    }
  }
}

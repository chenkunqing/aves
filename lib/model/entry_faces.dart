import 'package:aves/services/common/services.dart';

final EntryFaces entryFaces = EntryFaces._private();

class EntryFaces {
  final Map<int, int> _data = {};

  EntryFaces._private();

  Future<void> init() async {
    final loaded = await localMediaDb.loadAllEntryFaces();
    _data
      ..clear()
      ..addAll(loaded);
  }

  int get scannedCount => _data.length;

  bool isScanned(int entryId) => _data.containsKey(entryId);

  int? getFaceCount(int entryId) => _data[entryId];

  bool isTwoPersonPhoto(int entryId) => (_data[entryId] ?? 0) == 2;

  bool isMultiPersonPhoto(int entryId) => (_data[entryId] ?? 0) >= 3;

  bool isGroupPhoto(int entryId) => (_data[entryId] ?? 0) >= 2;

  Future<void> save(int entryId, int faceCount, String? boundingBoxes) async {
    _data[entryId] = faceCount;
    await localMediaDb.saveEntryFaces(entryId, faceCount, boundingBoxes);
  }

  Future<void> removeByIds(Set<int> ids) async {
    ids.forEach(_data.remove);
    await localMediaDb.removeEntryFacesByIds(ids);
  }

  Future<void> clear() async {
    _data.clear();
    await localMediaDb.clearEntryFaces();
  }
}

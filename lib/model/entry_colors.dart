import 'dart:ui';

import 'package:aves/services/common/services.dart';
import 'package:aves_utils/aves_utils.dart';

final EntryColors entryColors = EntryColors._private();

class EntryColors {
  final Map<int, List<int>> _data = {};

  EntryColors._private();

  Future<void> init() async {
    final loaded = await localMediaDb.loadAllEntryColors();
    _data
      ..clear()
      ..addAll(loaded);
  }

  int get indexedCount => _data.length;

  bool isIndexed(int entryId) => _data.containsKey(entryId);

  List<int>? getColors(int entryId) => _data[entryId];

  Future<void> save(int entryId, List<Color> colors) async {
    final argbValues = colors.map((c) => c.toARGB32()).toList();
    _data[entryId] = argbValues;
    await localMediaDb.saveEntryColors(entryId, argbValues);
  }

  Set<int> getMatchingEntryIds(int targetArgb) {
    final result = <int>{};
    for (final entry in _data.entries) {
      for (final color in entry.value) {
        if (ColorMatcher.isMatch(targetArgb, color)) {
          result.add(entry.key);
          break;
        }
      }
    }
    return result;
  }

  Future<void> removeByIds(Set<int> ids) async {
    ids.forEach(_data.remove);
    await localMediaDb.removeEntryColorsByIds(ids);
  }

  Future<void> clear() async {
    _data.clear();
    await localMediaDb.clearEntryColors();
  }
}

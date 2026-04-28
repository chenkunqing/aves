import 'dart:collection';

import 'package:aves/model/entry/entry.dart';
import 'package:flutter/foundation.dart';

class CandidateBasket extends ChangeNotifier {
  final LinkedHashMap<String, AvesEntry> _entriesByKey = LinkedHashMap();

  Iterable<AvesEntry> get entries => _entriesByKey.values;

  int get count => _entriesByKey.length;

  bool get isEmpty => _entriesByKey.isEmpty;

  bool get isNotEmpty => _entriesByKey.isNotEmpty;

  bool contains(AvesEntry entry) => _entriesByKey.containsKey(_keyFor(entry));

  bool containsAll(Iterable<AvesEntry> entries) => entries.isNotEmpty && entries.every(contains);

  int addAll(Iterable<AvesEntry> entries) {
    var addedCount = 0;
    for (final entry in entries) {
      final key = _keyFor(entry);
      if (!_entriesByKey.containsKey(key)) {
        addedCount++;
      }
      _entriesByKey[key] = entry;
    }
    if (addedCount > 0) {
      notifyListeners();
    }
    return addedCount;
  }

  int removeAll(Iterable<AvesEntry> entries) {
    var removedCount = 0;
    for (final entry in entries) {
      if (_entriesByKey.remove(_keyFor(entry)) != null) {
        removedCount++;
      }
    }
    if (removedCount > 0) {
      notifyListeners();
    }
    return removedCount;
  }

  void clear() {
    if (_entriesByKey.isEmpty) return;
    _entriesByKey.clear();
    notifyListeners();
  }

  static String _keyFor(AvesEntry entry) => '${entry.uri}::${entry.pageId ?? ''}';
}

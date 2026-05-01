import 'dart:collection';

import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/entry/extensions/favourites.dart';
import 'package:flutter/foundation.dart';

class OrganizeBasket extends ChangeNotifier {
  final LinkedHashMap<String, AvesEntry> _deletionEntries = LinkedHashMap();
  final Set<String> _movedEntries = {};

  Set<AvesEntry> get deletionEntries => _deletionEntries.values.toSet();

  int get deletionCount => _deletionEntries.length;

  bool isMarkedForDeletion(AvesEntry entry) => _deletionEntries.containsKey(_keyFor(entry));

  bool isMovedAway(AvesEntry entry) => _movedEntries.contains(_keyFor(entry));

  bool shouldSkip(AvesEntry entry) => isMarkedForDeletion(entry) || isMovedAway(entry);

  void addToMoved(AvesEntry entry) {
    _movedEntries.add(_keyFor(entry));
    notifyListeners();
  }

  void addToDeletion(AvesEntry entry) {
    _deletionEntries[_keyFor(entry)] = entry;
    notifyListeners();
  }

  void removeFromDeletion(AvesEntry entry) {
    _deletionEntries.remove(_keyFor(entry));
    notifyListeners();
  }

  void toggleFavourite(AvesEntry entry) {
    entry.toggleFavourite();
    notifyListeners();
  }

  void clear() {
    _deletionEntries.clear();
    notifyListeners();
  }

  static String _keyFor(AvesEntry entry) => '${entry.uri}::${entry.pageId ?? ''}';
}

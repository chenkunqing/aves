import 'dart:collection';

import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/entry/extensions/favourites.dart';
import 'package:flutter/foundation.dart';

class OrganizeBasket extends ChangeNotifier {
  final LinkedHashMap<String, AvesEntry> _deletionEntries = LinkedHashMap();
  final List<OrganizeUndoAction> _undoStack = [];

  Set<AvesEntry> get deletionEntries => _deletionEntries.values.toSet();

  int get deletionCount => _deletionEntries.length;

  bool get canUndo => _undoStack.isNotEmpty;

  bool isMarkedForDeletion(AvesEntry entry) => _deletionEntries.containsKey(_keyFor(entry));

  void addToDeletion(AvesEntry entry, int atIndex) {
    _deletionEntries[_keyFor(entry)] = entry;
    _undoStack.add(UndoMarkForDeletion(entry, atIndex));
    notifyListeners();
  }

  void removeFromDeletion(AvesEntry entry) {
    _deletionEntries.remove(_keyFor(entry));
    notifyListeners();
  }

  void toggleFavourite(AvesEntry entry) {
    final wasFavourite = entry.isFavourite;
    entry.toggleFavourite();
    _undoStack.add(UndoToggleFavourite(entry, wasFavourite));
    notifyListeners();
  }

  OrganizeUndoAction? undo() {
    if (_undoStack.isEmpty) return null;
    final action = _undoStack.removeLast();
    switch (action) {
      case UndoMarkForDeletion():
        _deletionEntries.remove(_keyFor(action.entry));
      case UndoToggleFavourite():
        if (action.wasFavourite) {
          action.entry.addToFavourites();
        } else {
          action.entry.removeFromFavourites();
        }
    }
    notifyListeners();
    return action;
  }

  void clear() {
    _deletionEntries.clear();
    _undoStack.clear();
    notifyListeners();
  }

  static String _keyFor(AvesEntry entry) => '${entry.uri}::${entry.pageId ?? ''}';
}

sealed class OrganizeUndoAction {
  final AvesEntry entry;
  OrganizeUndoAction(this.entry);
}

class UndoMarkForDeletion extends OrganizeUndoAction {
  final int atIndex;
  UndoMarkForDeletion(super.entry, this.atIndex);
}

class UndoToggleFavourite extends OrganizeUndoAction {
  final bool wasFavourite;
  UndoToggleFavourite(super.entry, this.wasFavourite);
}

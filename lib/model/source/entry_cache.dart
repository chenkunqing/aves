import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/entry/sort.dart';
import 'package:aves/model/filters/filters.dart';
import 'package:aves/model/filters/trash.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/services/common/services.dart';

class EntryCache {
  final Map<int, AvesEntry> _entriesById = {};

  Set<AvesEntry>? _visibleEntries, _trashedEntries;
  List<AvesEntry>? _sortedEntriesByDate;

  late Map<int?, int?> _savedDates;

  AvesEntry? getById(int id) => _entriesById[id];

  Set<AvesEntry> get all => Set.unmodifiable(_entriesById.values);

  Set<AvesEntry> get visible {
    _visibleEntries ??= Set.unmodifiable(_applyHiddenFilters(_entriesById.values));
    return _visibleEntries!;
  }

  Set<AvesEntry> get trashed {
    _trashedEntries ??= Set.unmodifiable(_applyTrashFilter(_entriesById.values));
    return _trashedEntries!;
  }

  List<AvesEntry> get sortedByDate {
    _sortedEntriesByDate ??= List.unmodifiable(visible.toList()..sort(AvesEntrySort.compareByDate));
    return _sortedEntriesByDate!;
  }

  void invalidate() {
    _visibleEntries = null;
    _trashedEntries = null;
    _sortedEntriesByDate = null;
  }

  Future<void> loadDates() async {
    _savedDates = Map.unmodifiable(await localMediaDb.loadDates());
  }

  void addEntries(Set<AvesEntry> entries) {
    if (entries.isEmpty) return;

    entries.where((entry) => entry.catalogDateMillis == null).forEach((entry) {
      entry.catalogDateMillis = _savedDates[entry.id];
    });

    final newEntriesById = Map.fromEntries(entries.map((entry) => MapEntry(entry.id, entry)));
    final newIds = newEntriesById.keys.toSet();
    disposeWhere((id, _) => newIds.contains(id));

    _entriesById.addAll(newEntriesById);
  }

  void disposeWhere(bool Function(int id, AvesEntry entry) test) {
    final todoEntries = _entriesById.entries.where((kv) => test(kv.key, kv.value)).toSet();
    todoEntries.forEach((kv) => _entriesById.remove(kv.key)?.dispose());
  }

  void disposeAll() => disposeWhere((_, _) => true);

  Iterable<AvesEntry> applyHiddenFilters(Iterable<AvesEntry> entries) => _applyHiddenFilters(entries);

  Set<CollectionFilter> _getAppHiddenFilters() => {
        ...settings.hiddenFilters,
      };

  Iterable<AvesEntry> _applyHiddenFilters(Iterable<AvesEntry> entries) {
    final hiddenFilters = {
      TrashFilter.instance,
      ..._getAppHiddenFilters(),
    };
    return entries.where((entry) => !hiddenFilters.any((filter) => filter.test(entry)));
  }

  Iterable<AvesEntry> _applyTrashFilter(Iterable<AvesEntry> entries) {
    final hiddenFilters = _getAppHiddenFilters();
    return entries.where(TrashFilter.instance.test).where((entry) => !hiddenFilters.any((filter) => filter.test(entry)));
  }
}

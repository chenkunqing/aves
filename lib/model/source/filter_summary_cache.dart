import 'package:aves/model/entry/entry.dart';

class FilterSummaryCache<K> {
  final Map<K, int> _countMap = {};
  final Map<K, int> _sizeMap = {};
  final Map<K, AvesEntry?> _recentEntryMap = {};

  bool get isEmpty => _countMap.isEmpty && _sizeMap.isEmpty && _recentEntryMap.isEmpty;

  int count(K key, int Function() compute) => _countMap.putIfAbsent(key, compute);

  int size(K key, int Function() compute) => _sizeMap.putIfAbsent(key, compute);

  AvesEntry? recentEntry(K key, AvesEntry? Function() compute) => _recentEntryMap.putIfAbsent(key, compute);

  void invalidate([Set<K>? keys]) {
    if (keys == null) {
      _countMap.clear();
      _sizeMap.clear();
      _recentEntryMap.clear();
    } else {
      for (final key in keys) {
        _countMap.remove(key);
        _sizeMap.remove(key);
        _recentEntryMap.remove(key);
      }
    }
  }

  void invalidateWhere(bool Function(K key) test) {
    _countMap.removeWhere((k, _) => test(k));
    _sizeMap.removeWhere((k, _) => test(k));
    _recentEntryMap.removeWhere((k, _) => test(k));
  }
}

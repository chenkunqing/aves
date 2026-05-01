import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/filters/covered/location.dart';
import 'package:aves/model/source/collection_source.dart';
import 'package:aves/model/source/filter_summary_cache.dart';
import 'package:aves/utils/collection_utils.dart';
import 'package:collection/collection.dart';

mixin StateMixin on SourceBase {
  final FilterSummaryCache<String> _stateSummary = FilterSummaryCache();

  void invalidateStateFilterSummary({
    Set<AvesEntry>? entries,
    Set<String>? stateCodes,
    bool notify = true,
  }) {
    if (_stateSummary.isEmpty) return;

    if (entries == null && stateCodes == null) {
      _stateSummary.invalidate();
    } else {
      stateCodes ??= {};
      if (entries != null) {
        stateCodes.addAll(entries.where((entry) => entry.hasAddress).map((entry) => entry.addressDetails?.stateCode).nonNulls);
      }
      _stateSummary.invalidate(stateCodes);
    }
    if (notify) {
      eventBus.fire(StateSummaryInvalidatedEvent(stateCodes));
    }
  }

  int stateEntryCount(LocationFilter filter) {
    final stateCode = filter.code;
    if (stateCode == null) return 0;
    return _stateSummary.count(stateCode, () => visibleEntries.where(filter.test).length);
  }

  int stateSize(LocationFilter filter) {
    final stateCode = filter.code;
    if (stateCode == null) return 0;
    return _stateSummary.size(stateCode, () => visibleEntries.where(filter.test).map((v) => v.sizeBytes).sum);
  }

  AvesEntry? stateRecentEntry(LocationFilter filter) {
    final stateCode = filter.code;
    if (stateCode == null) return null;
    return _stateSummary.recentEntry(stateCode, () => sortedEntriesByDate.firstWhereOrNull(filter.test));
  }
}

class StatesChangedEvent {}

class StateSummaryInvalidatedEvent {
  final Set<String>? stateCodes;

  const StateSummaryInvalidatedEvent(this.stateCodes);
}

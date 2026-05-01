import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/filters/covered/location.dart';
import 'package:aves/model/source/collection_source.dart';
import 'package:aves/model/source/filter_summary_cache.dart';
import 'package:aves/utils/collection_utils.dart';
import 'package:collection/collection.dart';

mixin PlaceMixin on SourceBase {
  final FilterSummaryCache<String> _placeSummary = FilterSummaryCache();

  void invalidatePlaceFilterSummary({
    Set<AvesEntry>? entries,
    Set<String>? places,
    bool notify = true,
  }) {
    if (_placeSummary.isEmpty) return;

    if (entries == null && places == null) {
      _placeSummary.invalidate();
    } else {
      places ??= {};
      if (entries != null) {
        places.addAll(entries.map((entry) => entry.addressDetails?.place).nonNulls);
      }
      _placeSummary.invalidate(places);
    }
    if (notify) {
      eventBus.fire(PlaceSummaryInvalidatedEvent(places));
    }
  }

  int placeEntryCount(LocationFilter filter) {
    return _placeSummary.count(filter.place, () => visibleEntries.where(filter.test).length);
  }

  int placeSize(LocationFilter filter) {
    return _placeSummary.size(filter.place, () => visibleEntries.where(filter.test).map((v) => v.sizeBytes).sum);
  }

  AvesEntry? placeRecentEntry(LocationFilter filter) {
    return _placeSummary.recentEntry(filter.place, () => sortedEntriesByDate.firstWhereOrNull(filter.test));
  }
}

class PlacesChangedEvent {}

class PlaceSummaryInvalidatedEvent {
  final Set<String>? places;

  const PlaceSummaryInvalidatedEvent(this.places);
}

import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/filters/covered/location.dart';
import 'package:aves/model/source/collection_source.dart';
import 'package:aves/model/source/filter_summary_cache.dart';
import 'package:aves/utils/collection_utils.dart';
import 'package:collection/collection.dart';

mixin CountryMixin on SourceBase {
  final FilterSummaryCache<String> _countrySummary = FilterSummaryCache();

  void invalidateCountryFilterSummary({
    Set<AvesEntry>? entries,
    Set<String>? countryCodes,
    bool notify = true,
  }) {
    if (_countrySummary.isEmpty) return;

    if (entries == null && countryCodes == null) {
      _countrySummary.invalidate();
    } else {
      countryCodes ??= {};
      if (entries != null) {
        countryCodes.addAll(entries.where((entry) => entry.hasAddress).map((entry) => entry.addressDetails?.countryCode).nonNulls);
      }
      _countrySummary.invalidate(countryCodes);
    }
    if (notify) {
      eventBus.fire(CountrySummaryInvalidatedEvent(countryCodes));
    }
  }

  int countryEntryCount(LocationFilter filter) {
    final countryCode = filter.code;
    if (countryCode == null) return 0;
    return _countrySummary.count(countryCode, () => visibleEntries.where(filter.test).length);
  }

  int countrySize(LocationFilter filter) {
    final countryCode = filter.code;
    if (countryCode == null) return 0;
    return _countrySummary.size(countryCode, () => visibleEntries.where(filter.test).map((v) => v.sizeBytes).sum);
  }

  AvesEntry? countryRecentEntry(LocationFilter filter) {
    final countryCode = filter.code;
    if (countryCode == null) return null;
    return _countrySummary.recentEntry(countryCode, () => sortedEntriesByDate.firstWhereOrNull(filter.test));
  }
}

class CountriesChangedEvent {}

class CountrySummaryInvalidatedEvent {
  final Set<String>? countryCodes;

  const CountrySummaryInvalidatedEvent(this.countryCodes);
}

import 'dart:math';

import 'package:aves/geo/countries.dart';
import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/entry/extensions/location.dart';
import 'package:aves/model/filters/covered/location.dart';
import 'package:aves/model/metadata/address.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/model/source/analysis_controller.dart';
import 'package:aves/model/source/analysis_step.dart';
import 'package:aves/model/source/batch_processor.dart';
import 'package:aves/model/source/collection_source.dart';
import 'package:aves/model/source/filter_summary_cache.dart';
import 'package:aves/utils/collection_utils.dart';
import 'package:aves/services/common/services.dart';
import 'package:aves_model/aves_model.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

mixin LocationMixin on SourceBase {
  static final _locatePlacesStep = AnalysisStep(
    batch: const BatchProcessor(commitThreshold: 200, stopCheckThreshold: 50),
    testPredicate: locatePlacesTest,
    forceFilter: (entry) => entry.hasGps,
    sourceState: SourceState.locatingPlaces,
  );

  // region Country filter summary

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

  // endregion

  // region State filter summary

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

  // endregion

  // region Place filter summary

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

  // endregion

  // region Location data

  List<String> sortedCountries = List.unmodifiable([]);
  List<String> sortedStates = List.unmodifiable([]);
  List<String> sortedPlaces = List.unmodifiable([]);

  Future<void> loadAddresses({Set<int>? ids}) async {
    final saved = await (ids != null ? localMediaDb.loadAddressesById(ids) : localMediaDb.loadAddresses());
    saved.forEach((metadata) => getEntryById(metadata.id)?.addressDetails = metadata);
    invalidateEntries();
    onAddressMetadataChanged();
  }

  Future<void> locateEntries(AnalysisController controller, Set<AvesEntry> candidateEntries) async {
    await _locateCountries(controller, candidateEntries);
    await _locatePlaces(controller, candidateEntries);

    final unlocatedIds = candidateEntries.where((entry) => !entry.hasGps).map((entry) => entry.id).toSet();
    if (unlocatedIds.isNotEmpty) {
      await localMediaDb.removeIds(unlocatedIds, dataTypes: {EntryDataType.address});
      onAddressMetadataChanged();
    }
  }

  static bool locateCountriesTest(AvesEntry entry) => entry.hasGps && !entry.hasAddress;

  static bool locatePlacesTest(AvesEntry entry) => entry.hasGps && !entry.hasFineAddress;

  Future<void> _locateCountries(AnalysisController controller, Set<AvesEntry> candidateEntries) async {
    if (controller.isStopping) return;

    final force = controller.force;
    final todo = (force ? candidateEntries.where((entry) => entry.hasGps) : candidateEntries.where(locateCountriesTest)).toSet();
    if (todo.isEmpty) return;

    state = SourceState.locatingCountries;
    var progressDone = 0;
    final progressTotal = todo.length;
    setProgress(done: progressDone, total: progressTotal);

    final countryCodeMap = await countryTopology.countryCodeMap(todo.map((entry) => entry.latLng!).toSet());
    final newAddresses = <AddressDetails>{};
    todo.forEach((entry) {
      final position = entry.latLng;
      final countryCode = countryCodeMap.entries.firstWhereOrNull((kv) => kv.value.contains(position))?.key;
      entry.setCountry(countryCode);
      if (entry.hasAddress) {
        newAddresses.add(entry.addressDetails!);
      }
      setProgress(done: ++progressDone, total: progressTotal);
    });
    if (newAddresses.isNotEmpty) {
      await localMediaDb.saveAddresses(Set.unmodifiable(newAddresses));
      onAddressMetadataChanged();
    }
  }

  Future<void> _locatePlaces(AnalysisController controller, Set<AvesEntry> candidateEntries) async {
    if (!await availability.canLocatePlaces) return;

    final force = controller.force;
    final latLngFactor = pow(10, 2);
    (int latitude, int longitude) approximateLatLng(AvesEntry entry) {
      final catalogMetadata = entry.catalogMetadata!;
      final lat = catalogMetadata.latitude!;
      final lng = catalogMetadata.longitude!;
      return ((lat * latLngFactor).round(), (lng * latLngFactor).round());
    }

    final knownLocations = <(int, int), AddressDetails?>{};

    final ran = await runAnalysisStep<AddressDetails>(
      step: _locatePlacesStep,
      controller: controller,
      candidateEntries: candidateEntries,
      onBeforeRun: (todo) {
        final located = visibleEntries.where((entry) => entry.hasGps).toSet().difference(todo);
        for (final entry in located) {
          knownLocations.putIfAbsent(approximateLatLng(entry), () => entry.addressDetails);
        }
      },
      process: (entry) async {
        final latLng = approximateLatLng(entry);
        if (knownLocations.containsKey(latLng)) {
          entry.addressDetails = knownLocations[latLng]?.copyWith(id: entry.id);
        } else {
          await entry.locatePlace(background: true, force: force, geocoderLocale: settings.appliedLocale);
          knownLocations[latLng] = entry.addressDetails;
        }
        return entry.hasFineAddress ? entry.addressDetails : null;
      },
      onCommit: (batch) async {
        await localMediaDb.saveAddresses(batch);
        onAddressMetadataChanged();
      },
    );
    if (ran) onAddressMetadataChanged();
  }

  void onAddressMetadataChanged() {
    updateLocations();
    eventBus.fire(AddressMetadataChangedEvent());
  }

  void updateLocations() {
    final locations = visibleEntries.map((entry) => entry.addressDetails).nonNulls.toList();

    final updatedPlaces = locations.map((address) => address.place).nonNulls.where((v) => v.isNotEmpty).toSet().toList()..sort(compareAsciiUpperCase);
    if (!listEquals(updatedPlaces, sortedPlaces)) {
      sortedPlaces = List.unmodifiable(updatedPlaces);
      eventBus.fire(PlacesChangedEvent());
    }

    final updatedStates = _getAreaByCode(
      locations: locations,
      getCode: (v) => v.stateCode,
      getName: (v) => v.stateName,
    );
    if (!listEquals(updatedStates, sortedStates)) {
      sortedStates = List.unmodifiable(updatedStates);
      invalidateStateFilterSummary();
      eventBus.fire(StatesChangedEvent());
    }

    final updatedCountries = _getAreaByCode(
      locations: locations,
      getCode: (v) => v.countryCode,
      getName: (v) => v.countryName,
    );
    if (!listEquals(updatedCountries, sortedCountries)) {
      sortedCountries = List.unmodifiable(updatedCountries);
      invalidateCountryFilterSummary();
      eventBus.fire(CountriesChangedEvent());
    }
  }

  List<String> _getAreaByCode({
    required List<AddressDetails> locations,
    required String? Function(AddressDetails address) getCode,
    required String? Function(AddressDetails address) getName,
  }) {
    final namesByCode = Map.fromEntries(
      locations.map((address) {
        final code = getCode(address);
        if (code == null || code.isEmpty) return null;
        return MapEntry(code, getName(address));
      }).nonNulls,
    );
    return namesByCode.entries.map((kv) {
      final code = kv.key;
      final name = kv.value;
      return '${name != null && name.isNotEmpty ? name : code}${LocationFilter.locationSeparator}$code';
    }).toList()..sort(compareAsciiUpperCase);
  }

  // endregion
}

class CountriesChangedEvent {}

class CountrySummaryInvalidatedEvent {
  final Set<String>? countryCodes;

  const CountrySummaryInvalidatedEvent(this.countryCodes);
}

class StatesChangedEvent {}

class StateSummaryInvalidatedEvent {
  final Set<String>? stateCodes;

  const StateSummaryInvalidatedEvent(this.stateCodes);
}

class PlacesChangedEvent {}

class PlaceSummaryInvalidatedEvent {
  final Set<String>? places;

  const PlaceSummaryInvalidatedEvent(this.places);
}

class AddressMetadataChangedEvent {}

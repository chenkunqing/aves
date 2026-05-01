import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/entry/extensions/catalog.dart';
import 'package:aves/model/filters/container/tag_group.dart';
import 'package:aves/model/filters/covered/tag.dart';
import 'package:aves/model/metadata/catalog.dart';
import 'package:aves/model/source/analysis_controller.dart';
import 'package:aves/model/source/batch_processor.dart';
import 'package:aves/model/source/collection_source.dart';
import 'package:aves/model/source/filter_summary_cache.dart';
import 'package:aves/services/common/services.dart';
import 'package:aves/utils/collection_utils.dart';
import 'package:aves_model/aves_model.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

mixin TagMixin on SourceBase {
  static const _batch = BatchProcessor(commitThreshold: 400, stopCheckThreshold: 100);

  List<String> sortedTags = List.unmodifiable([]);

  Future<void> loadCatalogMetadata({Set<int>? ids}) async {
    final saved = await (ids != null ? localMediaDb.loadCatalogMetadataById(ids) : localMediaDb.loadCatalogMetadata());
    saved.forEach((metadata) => getEntryById(metadata.id)?.catalogMetadata = metadata);
    invalidateEntries();
    onCatalogMetadataChanged();
  }

  static bool catalogEntriesTest(AvesEntry entry) => !entry.isCatalogued;

  Future<void> catalogEntries(AnalysisController controller, Set<AvesEntry> candidateEntries) async {
    if (controller.isStopping) return;

    final force = controller.force;
    final todo = force ? candidateEntries : candidateEntries.where(catalogEntriesTest).toSet();
    if (todo.isEmpty) return;

    state = SourceState.cataloguing;

    await _batch.run<CatalogMetadata>(
      controller: controller,
      entries: todo,
      process: (entry) async {
        await entry.catalog(background: true, force: force, persist: true);
        return entry.isCatalogued ? entry.catalogMetadata : null;
      },
      onCommit: (batch) async {
        await localMediaDb.saveCatalogMetadata(batch);
        onCatalogMetadataChanged();
      },
      onProgress: (done, total) => setProgress(done: done, total: total),
      progressOffset: controller.progressOffset,
      progressTotal: controller.progressTotal > 0 ? controller.progressTotal : null,
    );
    onCatalogMetadataChanged();
  }

  void onCatalogMetadataChanged() {
    updateTags();
    eventBus.fire(CatalogMetadataChangedEvent());
  }

  void updateTags() {
    final updatedTags = visibleEntries.expand((entry) => entry.tags).toSet().toList()..sort(compareAsciiUpperCaseNatural);
    if (!listEquals(updatedTags, sortedTags)) {
      sortedTags = List.unmodifiable(updatedTags);
      invalidateTagFilterSummary();
      eventBus.fire(TagsChangedEvent());
    }
  }

  // filter summary

  final FilterSummaryCache<String> _tagSummary = FilterSummaryCache();

  void invalidateTagFilterSummary({
    Set<AvesEntry>? entries,
    Set<String>? tags,
    bool notify = true,
  }) {
    if (_tagSummary.isEmpty) return;

    if (entries == null && tags == null) {
      _tagSummary.invalidate();
    } else {
      tags ??= {};
      if (entries != null) {
        tags.addAll(entries.where((entry) => entry.isCatalogued).expand((entry) => entry.tags));
      }
      _tagSummary.invalidate(tags.map((v) => TagFilter(v).key).toSet());

      // clear entries for all groups
      invalidateTagGroupFilterSummary(notify: false);
    }
    if (notify) {
      eventBus.fire(TagSummaryInvalidatedEvent(tags));
      eventBus.fire(const TagGroupSummaryInvalidatedEvent());
    }
  }

  void invalidateTagGroupFilterSummary({bool notify = true}) {
    _tagSummary.invalidateWhere((key) => key.startsWith('${TagGroupFilter.type}-'));

    if (notify) {
      eventBus.fire(const TagGroupSummaryInvalidatedEvent());
    }
  }

  int tagEntryCount(TagBaseFilter filter) {
    return _tagSummary.count(filter.key, () => visibleEntries.where(filter.test).length);
  }

  int tagSize(TagBaseFilter filter) {
    return _tagSummary.size(filter.key, () => visibleEntries.where(filter.test).map((v) => v.sizeBytes).sum);
  }

  AvesEntry? tagRecentEntry(TagBaseFilter filter) {
    return _tagSummary.recentEntry(filter.key, () => sortedEntriesByDate.firstWhereOrNull(filter.test));
  }
}

class CatalogMetadataChangedEvent {}

class TagsChangedEvent {}

class TagGroupSummaryInvalidatedEvent {
  const TagGroupSummaryInvalidatedEvent();
}

class TagSummaryInvalidatedEvent {
  final Set<String>? tags;

  const TagSummaryInvalidatedEvent(this.tags);
}

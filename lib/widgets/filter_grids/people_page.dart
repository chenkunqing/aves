import 'package:aves/model/filters/filters.dart';
import 'package:aves/model/filters/person.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/model/source/collection_source.dart';
import 'package:aves/model/source/person.dart';
import 'package:aves/theme/icons.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:aves/widgets/common/identity/empty.dart';
import 'package:aves/widgets/filter_grids/common/action_delegates/people_set.dart';
import 'package:aves/widgets/filter_grids/common/filter_nav_page.dart';
import 'package:aves/widgets/filter_grids/common/section_keys.dart';
import 'package:aves_model/aves_model.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PeopleListPage extends StatelessWidget {
  static const routeName = '/people';

  const PeopleListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final source = context.read<CollectionSource>();
    return Selector<Settings, (ChipSortFactor, bool, Set<CollectionFilter>)>(
      selector: (context, s) => (s.peopleSortFactor, s.peopleSortReverse, s.pinnedFilters),
      shouldRebuild: (t1, t2) {
        const eq = DeepCollectionEquality();
        return !(eq.equals(t1.$1, t2.$1) && eq.equals(t1.$2, t2.$2) && eq.equals(t1.$3, t2.$3));
      },
      builder: (context, s, child) {
        return StreamBuilder(
          stream: source.eventBus.on<PersonsChangedEvent>(),
          builder: (context, snapshot) {
            final gridItems = _getGridItems(source);
            return FilterNavigationPage<PersonFilter, PeopleChipSetActionDelegate>(
              source: source,
              title: context.l10n.peoplePageTitle,
              sortFactor: settings.peopleSortFactor,
              actionDelegate: PeopleChipSetActionDelegate(gridItems),
              filterSections: _groupToSections(gridItems),
              emptyBuilder: () => EmptyContent(
                icon: AIcons.people,
                text: context.l10n.peopleEmpty,
              ),
            );
          },
        );
      },
    );
  }

  static List<FilterGridItem<PersonFilter>> _getGridItems(CollectionSource source) {
    final filters = source.sortedPersonIds.map((id) => PersonFilter(id)).where((filter) => source.personEntryCount(filter) > 1).toSet();
    return FilterNavigationPage.sort(settings.peopleSortFactor, settings.peopleSortReverse, source, filters);
  }

  static Map<ChipSectionKey, List<FilterGridItem<PersonFilter>>> _groupToSections(Iterable<FilterGridItem<PersonFilter>> sortedMapEntries) {
    return {
      if (sortedMapEntries.isNotEmpty) const ChipSectionKey(): sortedMapEntries.toList(),
    };
  }
}

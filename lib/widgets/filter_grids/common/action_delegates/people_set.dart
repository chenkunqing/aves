import 'package:aves/app_mode.dart';
import 'package:aves/model/filters/filters.dart';
import 'package:aves/model/filters/person.dart';
import 'package:aves/model/person.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/model/source/collection_source.dart';
import 'package:aves/services/common/services.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:aves/widgets/filter_grids/common/action_delegates/chip_set.dart';
import 'package:aves/widgets/filter_grids/people_page.dart';
import 'package:aves_model/aves_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PeopleChipSetActionDelegate extends ChipSetActionDelegate<PersonFilter> {
  final Iterable<FilterGridItem<PersonFilter>> _items;

  PeopleChipSetActionDelegate(Iterable<FilterGridItem<PersonFilter>> items) : _items = items;

  @override
  Iterable<FilterGridItem<PersonFilter>> get allItems => _items;

  @override
  ChipSortFactor get sortFactor => settings.peopleSortFactor;

  @override
  set sortFactor(ChipSortFactor factor) => settings.peopleSortFactor = factor;

  @override
  bool get sortReverse => settings.peopleSortReverse;

  @override
  set sortReverse(bool value) => settings.peopleSortReverse = value;

  @override
  TileLayout get tileLayout => settings.getTileLayout(PeopleListPage.routeName);

  @override
  set tileLayout(TileLayout tileLayout) => settings.setTileLayout(PeopleListPage.routeName, tileLayout);

  @override
  bool isVisible(
    ChipSetAction action, {
    required AppMode appMode,
    required bool isSelecting,
    required int itemCount,
    required Set<PersonFilter> selectedFilters,
  }) {
    final isMain = appMode == AppMode.main;

    switch (action) {
      case .rename:
        return isMain && isSelecting && selectedFilters.length == 1;
      case .delete:
        return isMain && isSelecting;
      default:
        return super.isVisible(
          action,
          appMode: appMode,
          isSelecting: isSelecting,
          itemCount: itemCount,
          selectedFilters: selectedFilters,
        );
    }
  }

  @override
  void onActionSelected(BuildContext context, ChipSetAction action) {
    reportService.log('$runtimeType handles $action');
    switch (action) {
      case .rename:
        _rename(context);
      case .delete:
        _delete(context);
      default:
        break;
    }
    super.onActionSelected(context, action);
  }

  Future<void> _rename(BuildContext context) async {
    final filters = getSelectedFilters(context);
    if (filters.length != 1) return;

    final filter = filters.first;
    final person = personStore.getById(filter.personId);
    if (person == null) return;

    final controller = TextEditingController(text: person.name ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.personRenameDialogTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(context.l10n.applyButtonLabel),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty) return;

    await personStore.updatePerson(person.copyWith(name: newName));
    final source = context.read<CollectionSource>();
    source.updatePersons();
    browse(context);
  }

  Future<void> _delete(BuildContext context) async {
    final filters = getSelectedFilters(context);
    if (filters.isEmpty) return;

    for (final filter in filters) {
      await personStore.removePerson(filter.personId);
    }
    final source = context.read<CollectionSource>();
    source.updatePersons();
    browse(context);
  }
}

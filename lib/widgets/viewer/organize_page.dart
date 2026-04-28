import 'package:aves/app_mode.dart';
import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/organize_basket.dart';
import 'package:aves/model/source/collection_lens.dart';
import 'package:aves/model/source/collection_source.dart';
import 'package:aves/theme/icons.dart';
import 'package:aves/utils/android_file_utils.dart';
import 'package:aves_model/aves_model.dart';
import 'package:aves/widgets/common/action_mixins/entry_editor.dart';
import 'package:aves/widgets/common/action_mixins/entry_storage.dart';
import 'package:aves/widgets/common/action_mixins/feedback.dart';
import 'package:aves/widgets/common/action_mixins/permission_aware.dart';
import 'package:aves/widgets/common/action_mixins/size_aware.dart';
import 'package:aves/widgets/common/basic/scaffold.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:aves/widgets/common/identity/empty.dart';
import 'package:aves/widgets/viewer/organize/organize_card_stack.dart';
import 'package:aves/widgets/viewer/organize/organize_exit_dialog.dart';
import 'package:aves/widgets/viewer/organize/organize_overlay.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class OrganizePage extends StatefulWidget {
  static const routeName = '/collection/organize';

  final CollectionLens collection;

  const OrganizePage({
    super.key,
    required this.collection,
  });

  @override
  State<OrganizePage> createState() => _OrganizePageState();
}

class _OrganizePageState extends State<OrganizePage> {
  final ValueNotifier<AppMode> _appModeNotifier = ValueNotifier(AppMode.organize);
  final OrganizeBasket _basket = OrganizeBasket();
  final ValueNotifier<int> _indexNotifier = ValueNotifier(0);
  final GlobalKey<OrganizeCardStackState> _cardStackKey = GlobalKey();
  late final CollectionLens _organizeCollection;
  late final List<AvesEntry> _entries;
  final _actionDelegate = _OrganizeActionDelegate();
  final ValueNotifier<bool> _showHintsNotifier = ValueNotifier(true);

  CollectionSource get source => widget.collection.source;

  @override
  void initState() {
    super.initState();
    _organizeCollection = CollectionLens(
      source: source,
      listenToSource: false,
      fixedSort: true,
      fixedSelection: List.of(widget.collection.sortedEntries),
    );
    _entries = _organizeCollection.sortedEntries.toList();
  }

  @override
  void dispose() {
    _appModeNotifier.dispose();
    _basket.dispose();
    _indexNotifier.dispose();
    _showHintsNotifier.dispose();
    _organizeCollection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableProvider<ValueNotifier<AppMode>>.value(
      value: _appModeNotifier,
      child: ChangeNotifierProvider<OrganizeBasket>.value(
        value: _basket,
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _onExitRequested();
          },
          child: AvesScaffold(
            body: _entries.isEmpty
                ? EmptyContent(
                    icon: AIcons.image,
                    text: context.l10n.collectionEmptyImages,
                    alignment: Alignment.center,
                  )
                : Stack(
                    children: [
                      Container(color: Colors.black),
                      Center(
                        child: OrganizeCardStack(
                          key: _cardStackKey,
                          entries: _entries,
                          indexNotifier: _indexNotifier,
                          onFirstInteraction: () => _showHintsNotifier.value = false,
                        ),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: _showHintsNotifier,
                        builder: (context, showHints, child) {
                          return OrganizeOverlay(
                            indexNotifier: _indexNotifier,
                            totalCount: _entries.length,
                            onUndo: _onUndo,
                            showHints: showHints,
                          );
                        },
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  void _onUndo() {
    final action = _basket.undo();
    if (action is UndoMarkForDeletion) {
      _cardStackKey.currentState?.goToIndex(action.atIndex);
    }
  }

  Future<void> _onExitRequested() async {
    if (_basket.deletionCount == 0) {
      Navigator.pop(context);
      return;
    }

    final confirmed = await showOrganizeExitDialog(context, _basket.deletionCount);
    if (!mounted) return;

    if (confirmed == true) {
      final entries = _basket.deletionEntries;
      final success = await _actionDelegate.doQuickMove(
        context,
        moveType: MoveType.toBin,
        entriesByDestination: {AndroidFileUtils.trashDirPath: entries},
        skipUndatedCheck: true,
      );
      if (!success || !mounted) return;
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }
}

class _OrganizeActionDelegate with FeedbackMixin, PermissionAwareMixin, SizeAwareMixin, EntryEditorMixin, EntryStorageMixin {}

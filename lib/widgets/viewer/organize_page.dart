import 'package:aves/app_mode.dart';
import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/organize_basket.dart';
import 'package:aves/model/settings/settings.dart';
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
import 'package:aves/widgets/dialogs/filter_editors/create_stored_album_dialog.dart';
import 'package:aves/widgets/viewer/organize/organize_card_stack.dart';
import 'package:aves/widgets/viewer/organize/organize_exit_dialog.dart';
import 'package:aves/widgets/viewer/organize/organize_overlay.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class OrganizePage extends StatefulWidget {
  static const routeName = '/collection/organize';

  final CollectionLens collection;
  final int initialIndex;

  const OrganizePage({
    super.key,
    required this.collection,
    this.initialIndex = 0,
  });

  @override
  State<OrganizePage> createState() => _OrganizePageState();
}

class _OrganizePageState extends State<OrganizePage> {
  final ValueNotifier<AppMode> _appModeNotifier = ValueNotifier(AppMode.organize);
  final OrganizeBasket _basket = OrganizeBasket();
  late final ValueNotifier<int> _indexNotifier;
  final GlobalKey<OrganizeCardStackState> _cardStackKey = GlobalKey();
  late final CollectionLens _organizeCollection;
  late final List<AvesEntry> _entries;
  final _actionDelegate = _OrganizeActionDelegate();
  late final ValueNotifier<bool> _showHintsNotifier;
  final ValueNotifier<int> _albumOrderNotifier = ValueNotifier(0);
  final ValueNotifier<String?> _undoMessageNotifier = ValueNotifier(null);
  final ValueNotifier<bool> _isMoveMode = ValueNotifier(false);

  CollectionSource get source => widget.collection.source;

  @override
  void initState() {
    super.initState();
    _showHintsNotifier = ValueNotifier(!settings.hasSeenOrganizeHints);
    _indexNotifier = ValueNotifier(widget.initialIndex);
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
    _albumOrderNotifier.dispose();
    _undoMessageNotifier.dispose();
    _isMoveMode.dispose();
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
                      Container(color: Theme.of(context).colorScheme.surface),
                      Center(
                        child: OrganizeCardStack(
                          key: _cardStackKey,
                          entries: _entries,
                          indexNotifier: _indexNotifier,
                          onFirstInteraction: () {
                            _showHintsNotifier.value = false;
                            settings.hasSeenOrganizeHints = true;
                          },
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
                            onShowHints: () => _showHintsNotifier.value = true,
                            onCopyToAlbum: _onCopyToAlbum,
                            onCreateAlbum: _onCreateAlbum,
                            albumOrderNotifier: _albumOrderNotifier,
                            undoMessageNotifier: _undoMessageNotifier,
                            isMoveMode: _isMoveMode,
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
    if (action == null) return;

    if (action is UndoMarkForDeletion) {
      _cardStackKey.currentState?.goToIndex(action.atIndex);
    }

    final l10n = context.l10n;
    final message = switch (action) {
      UndoMarkForDeletion() => l10n.organizeUndoDeletion,
      UndoToggleFavourite() => l10n.organizeUndoFavourite,
    };
    _undoMessageNotifier.value = message;
  }

  Future<void> _onCreateAlbum() async {
    final albumPath = await showDialog<String>(
      context: context,
      builder: (context) => const CreateStoredAlbumDialog(),
    );
    if (albumPath == null || !mounted) return;

    source.createStoredAlbum(albumPath);
    _albumOrderNotifier.value++;
    await _onCopyToAlbum(albumPath);
  }

  Future<void> _onCopyToAlbum(String albumPath) async {
    final currentIndex = _indexNotifier.value;
    if (currentIndex >= _entries.length) return;

    final entry = _entries[currentIndex];
    final moveType = _isMoveMode.value ? MoveType.move : MoveType.copy;
    final innerContext = _cardStackKey.currentContext ?? context;
    final success = await _actionDelegate.doQuickMove(
      innerContext,
      moveType: moveType,
      entriesByDestination: {albumPath: {entry}},
      skipUndatedCheck: true,
      onSuccess: () {
        settings.recentDestinationAlbums = settings.recentDestinationAlbums
          ..remove(albumPath)
          ..insert(0, albumPath);
        _albumOrderNotifier.value++;
      },
    );
    if (!success || !mounted) return;

    if (moveType == MoveType.move) {
      _basket.addToMoved(entry);
    }

    final l10n = context.l10n;
    final isCopy = moveType == MoveType.copy;
    _undoMessageNotifier.value = isCopy
        ? l10n.collectionCopySuccessFeedback(1)
        : l10n.collectionMoveSuccessFeedback(1);
    _cardStackKey.currentState?.goToIndex(currentIndex + 1);
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
      final innerContext = _cardStackKey.currentContext ?? context;
      final success = await _actionDelegate.doQuickMove(
        innerContext,
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

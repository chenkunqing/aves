import 'package:aves/app_mode.dart';
import 'package:aves/model/candidate_basket.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/services/app_service.dart';
import 'package:aves/services/common/services.dart';
import 'package:aves/widgets/common/action_mixins/entry_editor.dart';
import 'package:aves/widgets/common/action_mixins/entry_storage.dart';
import 'package:aves/widgets/common/action_mixins/feedback.dart';
import 'package:aves/widgets/common/action_mixins/permission_aware.dart';
import 'package:aves/widgets/common/action_mixins/size_aware.dart';
import 'package:aves/widgets/collection/collection_page.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:aves/widgets/common/identity/aves_app_bar.dart';
import 'package:aves/widgets/dialogs/aves_dialog.dart';
import 'package:aves/model/source/collection_source.dart';
import 'package:aves_model/aves_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CandidateBasketBar extends StatelessWidget with FeedbackMixin, PermissionAwareMixin, SizeAwareMixin, EntryEditorMixin, EntryStorageMixin {
  final bool padBottomSafeArea;

  static double get contentHeight => kMinInteractiveDimension;

  static double get height => contentHeight + AvesFloatingBar.margin.vertical;

  const CandidateBasketBar({
    super.key,
    required this.padBottomSafeArea,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: padBottomSafeArea,
      child: AvesFloatingBar(
        builder: (context, backgroundColor, child) => Material(
          color: backgroundColor,
          child: SizedBox(
            height: contentHeight,
            child: child,
          ),
        ),
        child: Selector<CandidateBasket, int>(
          selector: (context, basket) => basket.count,
          builder: (context, count, child) {
            return Padding(
              padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: count > 0 ? () => _preview(context) : null,
                      child: Row(
                        children: [
                          const Icon(Icons.shopping_basket_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              countLabel(context, count),
                              softWrap: false,
                              overflow: TextOverflow.fade,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('candidate-basket-save'),
                    icon: const Icon(Icons.save_alt_outlined),
                    onPressed: count > 0 ? () => _saveToAlbum(context) : null,
                    tooltip: saveToAlbumLabel(context),
                  ),
                  IconButton(
                    key: const Key('candidate-basket-share'),
                    icon: const Icon(Icons.share_outlined),
                    onPressed: count > 0 ? () => _share(context) : null,
                    tooltip: context.l10n.entryActionShare,
                  ),
                  IconButton(
                    key: const Key('candidate-basket-clear'),
                    icon: const Icon(Icons.clear),
                    onPressed: count > 0 ? () => context.read<CandidateBasket>().clear() : null,
                    tooltip: context.l10n.clearTooltip,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _preview(BuildContext context) {
    final source = context.read<CollectionSource>();
    final entries = context.read<CandidateBasket>().entries.toList();
    if (entries.isEmpty) return;

    Navigator.maybeOf(context)?.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: CollectionPage.routeName),
        builder: (context) => CollectionPage(
          source: source,
          filters: const {},
          fixedSelection: entries,
        ),
      ),
    );
  }

  Future<void> _saveToAlbum(BuildContext context) async {
    final basket = context.read<CandidateBasket>();
    final entries = basket.entries.toSet();
    if (entries.isEmpty) return;

    final completed = await doMove(
      context,
      moveType: MoveType.copy,
      entries: entries,
    );
    if (completed) {
      basket.clear();
    }
  }

  Future<void> _share(BuildContext context) async {
    final entries = context.read<CandidateBasket>().entries.toList();
    if (entries.isEmpty) return;

    try {
      if (!await appService.shareEntries(entries)) {
        await showNoMatchingAppDialog(context);
      }
    } on TooManyItemsException catch (_) {
      await showWarningDialog(
        context: context,
        message: context.l10n.tooManyItemsErrorDialogMessage,
      );
    }
  }

  static String countLabel(BuildContext context, int count) {
    final countText = context.l10n.itemCount(count);
    return context.locale.startsWith('zh') ? '\u5019\u9009\u7bee - $countText' : 'Candidate basket - $countText';
  }

  static String candidateBasketTitle(BuildContext context) => context.locale.startsWith('zh') ? '\u5019\u9009\u680f' : 'Candidate basket';

  static String saveToAlbumLabel(BuildContext context) => context.locale.startsWith('zh') ? '\u4fdd\u5b58\u5230\u76f8\u518c' : 'Save to album';

  static String addActionLabel(BuildContext context) => context.locale.startsWith('zh') ? '\u52a0\u5165\u5019\u9009\u7bee' : 'Add to basket';

  static String removeActionLabel(BuildContext context) => context.locale.startsWith('zh') ? '\u79fb\u51fa\u5019\u9009\u7bee' : 'Remove from basket';

  static String addedFeedback(BuildContext context, int count) {
    final countText = context.l10n.itemCount(count);
    return context.locale.startsWith('zh') ? '\u5df2\u52a0\u5165\u5019\u9009\u7bee\uff1a$countText' : 'Added to basket: $countText';
  }

  static String removedFeedback(BuildContext context, int count) {
    final countText = context.l10n.itemCount(count);
    return context.locale.startsWith('zh') ? '\u5df2\u4ece\u5019\u9009\u7bee\u79fb\u51fa\uff1a$countText' : 'Removed from basket: $countText';
  }
}

class CandidateBasketPaddingSliver extends StatelessWidget {
  const CandidateBasketPaddingSliver({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Selector<CandidateBasket, int>(
        selector: (context, basket) => basket.count,
        builder: (context, count, child) {
          final appMode = context.select<ValueNotifier<AppMode>, AppMode>((v) => v.value);
          if (settings.useTvLayout || count == 0 || appMode != AppMode.main) return const SizedBox();

          final canNavigate = context.select<ValueNotifier<AppMode>, bool>((v) => v.value.canNavigate);
          final enableBottomNavigationBar = context.select<Settings, bool>((v) => v.enableBottomNavigationBar);
          final showBottomNavigationBar = canNavigate && enableBottomNavigationBar;
          final bottomSafeArea = showBottomNavigationBar ? 0.0 : MediaQuery.paddingOf(context).bottom;
          return SizedBox(height: CandidateBasketBar.height + bottomSafeArea);
        },
      ),
    );
  }
}

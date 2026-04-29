import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/filters/covered/stored_album.dart';
import 'package:aves/model/filters/filters.dart';
import 'package:aves/model/organize_basket.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/model/source/collection_source.dart';
import 'package:aves/theme/icons.dart';
import 'package:aves/theme/themes.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:aves/widgets/common/thumbnail/image.dart';
import 'package:aves/widgets/filter_grids/common/filter_nav_page.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class OrganizeOverlay extends StatelessWidget {
  final ValueNotifier<int> indexNotifier;
  final int totalCount;
  final VoidCallback onUndo;
  final bool showHints;
  final VoidCallback onShowHints;
  final Future<void> Function(String albumPath) onCopyToAlbum;
  final Future<void> Function() onCreateAlbum;
  final ValueNotifier<int> albumOrderNotifier;
  final ValueNotifier<String?> undoMessageNotifier;
  final ValueNotifier<bool> isMoveMode;

  const OrganizeOverlay({
    super.key,
    required this.indexNotifier,
    required this.totalCount,
    required this.onUndo,
    required this.showHints,
    required this.onShowHints,
    required this.onCopyToAlbum,
    required this.onCreateAlbum,
    required this.albumOrderNotifier,
    required this.undoMessageNotifier,
    required this.isMoveMode,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Stack(
      children: [
        if (showHints) _buildHints(context),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildBottomSection(context, l10n),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: _buildTopBar(context),
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final blurred = settings.enableBlurEffect;
    final overlayBg = Themes.overlayBackgroundColor(brightness: theme.brightness, blurred: blurred);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close),
              color: colorScheme.onSurface,
              onPressed: () => Navigator.maybePop(context),
            ),
            const Spacer(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<int>(
                  valueListenable: indexNotifier,
                  builder: (context, index, child) {
                    final displayIndex = (index + 1).clamp(1, totalCount);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: overlayBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '$displayIndex / $totalCount',
                        style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline, size: 20),
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                  padding: const EdgeInsets.only(left: 4),
                  constraints: const BoxConstraints(),
                  onPressed: onShowHints,
                ),
              ],
            ),
            const Spacer(),
            Selector<OrganizeBasket, int>(
              selector: (context, basket) => basket.deletionCount,
              builder: (context, count, child) {
                if (count == 0) return const SizedBox(width: 48);
                return GestureDetector(
                  onTap: () => _showDeletionPreview(context),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(AIcons.bin, size: 24, color: colorScheme.onSurface),
                        Positioned(
                          top: 4,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                            child: Text(
                              '$count',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSection(BuildContext context, dynamic l10n) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _UndoMessageBubble(notifier: undoMessageNotifier),
                const SizedBox(width: 8),
                Selector<OrganizeBasket, bool>(
                  selector: (context, basket) => basket.canUndo,
                  builder: (context, canUndo, child) {
                    return FloatingActionButton.small(
                      heroTag: 'organize_undo',
                      onPressed: canUndo ? onUndo : null,
                      backgroundColor: canUndo ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest.withValues(alpha: 0.24),
                      child: Icon(
                        Icons.undo,
                        color: canUndo ? colorScheme.onPrimaryContainer : colorScheme.onSurface.withValues(alpha: 0.38),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          _OrganizeAlbumStrip(onCopyToAlbum: onCopyToAlbum, onCreateAlbum: onCreateAlbum, albumOrderNotifier: albumOrderNotifier, isMoveMode: isMoveMode),
        ],
      ),
    );
  }

  Widget _buildHints(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 100),
            _HintChip(icon: Icons.arrow_upward, label: l10n.organizeSwipeUpHint, color: Colors.red),
            const SizedBox(height: 8),
            _HintChip(icon: Icons.arrow_downward, label: l10n.organizeSwipeDownHint, color: Colors.amber),
            const SizedBox(height: 8),
            _HintChip(icon: Icons.swap_horiz, label: l10n.organizeSwipeLeftRightHint, color: Colors.blue),
          ],
        ),
      ),
    );
  }
}

class _OrganizeAlbumStrip extends StatelessWidget {
  final Future<void> Function(String albumPath) onCopyToAlbum;
  final Future<void> Function() onCreateAlbum;
  final ValueNotifier<int> albumOrderNotifier;
  final ValueNotifier<bool> isMoveMode;

  const _OrganizeAlbumStrip({required this.onCopyToAlbum, required this.onCreateAlbum, required this.albumOrderNotifier, required this.isMoveMode});

  List<String> _buildAlbumList(CollectionSource source) {
    final rawAlbums = source.rawAlbums;
    final recent = settings.recentDestinationAlbums.where(rawAlbums.contains).toList();
    final remaining = rawAlbums.whereNot(recent.contains).map((album) => StoredAlbumFilter(album, null)).toSet();
    final sorted = remaining.map((filter) => FilterGridItem(filter, source.recentEntry(filter))).toList()
      ..sort(FilterNavigationPage.compareFiltersByDate);
    return [...recent, ...sorted.map((v) => v.filter.album)];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final source = context.read<CollectionSource>();
    final colorScheme = Theme.of(context).colorScheme;
    final onSurfaceMuted = colorScheme.onSurface.withValues(alpha: 0.7);

    return ValueListenableBuilder<int>(
      valueListenable: albumOrderNotifier,
      builder: (context, _, child) {
        final albums = _buildAlbumList(source);

        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer.withValues(alpha: 0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: isMoveMode,
                builder: (context, isMove, child) {
                  return GestureDetector(
                    onTap: () => isMoveMode.value = !isMoveMode.value,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16, top: 12, bottom: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isMove ? Icons.content_cut : Icons.copy,
                            size: 14,
                            color: isMove ? Colors.orange : onSurfaceMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isMove ? l10n.organizeMoveToAlbum : l10n.organizeCopyToAlbum,
                            style: TextStyle(
                              color: isMove ? Colors.orange : onSurfaceMuted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.swap_vert,
                            size: 14,
                            color: isMove ? Colors.orange : onSurfaceMuted,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  itemCount: albums.length + 1,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _AlbumChip(
                        albumPath: '',
                        displayName: l10n.newAlbumDialogTitle,
                        icon: Icons.add,
                        onTap: onCreateAlbum,
                      );
                    }
                    final album = albums[index - 1];
                    final displayName = source.getStoredAlbumDisplayName(context, album);
                    return _AlbumChip(
                      albumPath: album,
                      displayName: displayName,
                      onTap: () => onCopyToAlbum(album),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

class _AlbumChip extends StatelessWidget {
  final String albumPath;
  final String displayName;
  final IconData icon;
  final VoidCallback onTap;

  static const _maxChars = 8;

  const _AlbumChip({
    required this.albumPath,
    required this.displayName,
    this.icon = Icons.download,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final truncated = displayName.length > _maxChars ? '${displayName.substring(0, _maxChars)}...' : displayName;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: colorScheme.onSurface.withValues(alpha: 0.7)),
            const SizedBox(height: 2),
            Text(
              truncated,
              style: TextStyle(color: colorScheme.onSurface, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.clip,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

void _showDeletionPreview(BuildContext context) {
  final basket = context.read<OrganizeBasket>();
  final entries = basket.deletionEntries.toList();
  if (entries.isEmpty) return;

  final dpr = MediaQuery.devicePixelRatioOf(context);
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final blurred = settings.enableBlurEffect;
  final overlayBg = Themes.overlayBackgroundColor(brightness: theme.brightness, blurred: blurred);

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.5),
    builder: (sheetContext) {
      return ChangeNotifierProvider<OrganizeBasket>.value(
        value: basket,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.38),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Selector<OrganizeBasket, int>(
                selector: (context, b) => b.deletionCount,
                builder: (context, count, child) {
                  return Text(
                    context.l10n.organizeMarkedForDeletion(count),
                    style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                  );
                },
              ),
            ),
            Flexible(
              child: Selector<OrganizeBasket, Set<AvesEntry>>(
                selector: (context, b) => b.deletionEntries,
                builder: (context, currentEntries, child) {
                  final items = currentEntries.toList();
                  if (items.isEmpty) {
                    Navigator.pop(sheetContext);
                    return const SizedBox();
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final entry = items[index];
                      return GestureDetector(
                        onTap: () {
                          basket.removeFromDeletion(entry);
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: ThumbnailImage(
                                entry: entry,
                                extent: 100,
                                devicePixelRatio: dpr,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: overlayBg,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.close, size: 14, color: colorScheme.onSurface),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _UndoMessageBubble extends StatefulWidget {
  final ValueNotifier<String?> notifier;

  const _UndoMessageBubble({required this.notifier});

  @override
  State<_UndoMessageBubble> createState() => _UndoMessageBubbleState();
}

class _UndoMessageBubbleState extends State<_UndoMessageBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  String? _message;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_controller);
    widget.notifier.addListener(_onMessage);
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_onMessage);
    _controller.dispose();
    super.dispose();
  }

  void _onMessage() {
    final msg = widget.notifier.value;
    if (msg == null) return;
    setState(() => _message = msg);
    _controller.forward(from: 0);
    widget.notifier.value = null;
  }

  @override
  Widget build(BuildContext context) {
    if (_message == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final overlayBg = Themes.overlayBackgroundColor(brightness: theme.brightness, blurred: settings.enableBlurEffect);

    return FadeTransition(
      opacity: _opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: overlayBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          _message!,
          style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
        ),
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _HintChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}

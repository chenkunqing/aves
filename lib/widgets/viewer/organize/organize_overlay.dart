import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/filters/covered/stored_album.dart';
import 'package:aves/model/filters/filters.dart';
import 'package:aves/model/organize_basket.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/model/source/collection_source.dart';
import 'package:aves/theme/icons.dart';
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
  final Future<void> Function(String albumPath) onCopyToAlbum;
  final ValueNotifier<int> albumOrderNotifier;

  const OrganizeOverlay({
    super.key,
    required this.indexNotifier,
    required this.totalCount,
    required this.onUndo,
    required this.showHints,
    required this.onCopyToAlbum,
    required this.albumOrderNotifier,
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close),
              color: Colors.white,
              onPressed: () => Navigator.maybePop(context),
            ),
            const Spacer(),
            ValueListenableBuilder<int>(
              valueListenable: indexNotifier,
              builder: (context, index, child) {
                final displayIndex = (index + 1).clamp(1, totalCount);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$displayIndex / $totalCount',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                );
              },
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
                        const Icon(AIcons.bin, size: 24, color: Colors.white),
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
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Selector<OrganizeBasket, bool>(
                  selector: (context, basket) => basket.canUndo,
                  builder: (context, canUndo, child) {
                    return FloatingActionButton.small(
                      heroTag: 'organize_undo',
                      onPressed: canUndo ? onUndo : null,
                      backgroundColor: canUndo ? Colors.white : Colors.white24,
                      child: Icon(
                        Icons.undo,
                        color: canUndo ? Colors.black87 : Colors.white38,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          _OrganizeAlbumStrip(onCopyToAlbum: onCopyToAlbum, albumOrderNotifier: albumOrderNotifier),
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
  final ValueNotifier<int> albumOrderNotifier;

  const _OrganizeAlbumStrip({required this.onCopyToAlbum, required this.albumOrderNotifier});

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

    return ValueListenableBuilder<int>(
      valueListenable: albumOrderNotifier,
      builder: (context, _, child) {
        final albums = _buildAlbumList(source);
        if (albums.isEmpty) return const SizedBox();

        return Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
                child: Text(
                  l10n.organizeCopyToAlbum,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  itemCount: albums.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final album = albums[index];
                    final displayName = source.getStoredAlbumDisplayName(context, album);
                    return _AlbumChip(
                      albumPath: album,
                      displayName: displayName,
                      onTap: () => onCopyToAlbum(album),
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
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
  final VoidCallback onTap;

  static const _maxChars = 8;

  const _AlbumChip({
    required this.albumPath,
    required this.displayName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final truncated = displayName.length > _maxChars ? '${displayName.substring(0, _maxChars)}...' : displayName;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.download, size: 22, color: Colors.white70),
            const SizedBox(height: 2),
            Text(
              truncated,
              style: const TextStyle(color: Colors.white, fontSize: 10),
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
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.grey[900],
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
                color: Colors.white38,
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
                    style: const TextStyle(color: Colors.white, fontSize: 14),
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
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
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

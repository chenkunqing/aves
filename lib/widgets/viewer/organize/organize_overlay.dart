import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/organize_basket.dart';
import 'package:aves/theme/icons.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:aves/widgets/common/thumbnail/image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class OrganizeOverlay extends StatelessWidget {
  final ValueNotifier<int> indexNotifier;
  final int totalCount;
  final VoidCallback onUndo;
  final bool showHints;

  const OrganizeOverlay({
    super.key,
    required this.indexNotifier,
    required this.totalCount,
    required this.onUndo,
    required this.showHints,
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
          child: _buildBottomBar(context, l10n),
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
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, dynamic l10n) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Selector<OrganizeBasket, int>(
              selector: (context, basket) => basket.deletionCount,
              builder: (context, count, child) {
                if (count == 0) return const SizedBox(width: 48);
                return GestureDetector(
                  onTap: () => _showDeletionPreview(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(AIcons.bin, size: 18, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          l10n.organizeMarkedForDeletion(count),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
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

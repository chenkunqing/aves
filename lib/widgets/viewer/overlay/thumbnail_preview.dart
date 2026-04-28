import 'dart:math';

import 'package:aves/model/entry/entry.dart';
import 'package:aves/theme/durations.dart';
import 'package:aves/widgets/common/grid/theme.dart';
import 'package:aves/widgets/common/thumbnail/decorated.dart';
import 'package:aves/widgets/common/thumbnail/image.dart';
import 'package:aves/widgets/viewer/controls/notifications.dart';
import 'package:flutter/material.dart';

class ViewerThumbnailPreview extends StatefulWidget {
  final List<AvesEntry> entries;
  final int displayedIndex;
  final double availableWidth;

  static const double _extent = 48;
  static const double _borderWidth = 2;
  static const double _separatorWidth = 2;
  static const double _verticalPadding = 4;

  const ViewerThumbnailPreview({
    super.key,
    required this.entries,
    required this.displayedIndex,
    required this.availableWidth,
  });

  @override
  State<ViewerThumbnailPreview> createState() => _ViewerThumbnailPreviewState();

  static double get preferredHeight => _extent + _borderWidth * 2 + _verticalPadding * 2;
}

class _ViewerThumbnailPreviewState extends State<ViewerThumbnailPreview> {
  late final ValueNotifier<int> _entryIndexNotifier;
  late ScrollController _scrollController;
  final ValueNotifier<bool> _cancellableNotifier = ValueNotifier(true);
  bool _isAnimating = false;
  bool _isScrolling = false;

  List<AvesEntry> get entries => widget.entries;

  int get entryCount => entries.length;

  static const _extent = ViewerThumbnailPreview._extent;
  static const _sep = ViewerThumbnailPreview._separatorWidth;
  static const _border = ViewerThumbnailPreview._borderWidth;
  static const _fixedItemWidth = _extent + _sep;

  double get _marginWidth => max(0.0, (widget.availableWidth - _extent) / 2);

  @override
  void initState() {
    super.initState();
    _entryIndexNotifier = ValueNotifier(widget.displayedIndex);
    _scrollController = ScrollController(
      initialScrollOffset: _scrollOffsetForIndex(widget.displayedIndex),
    );
    _scrollController.addListener(_onScrollChanged);
    _entryIndexNotifier.addListener(_onIndexChanged);
  }

  @override
  void didUpdateWidget(covariant ViewerThumbnailPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.displayedIndex != widget.displayedIndex) {
      _entryIndexNotifier.value = widget.displayedIndex;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    _entryIndexNotifier.dispose();
    _cancellableNotifier.dispose();
    super.dispose();
  }

  double _currentItemDisplayWidth(AvesEntry entry) {
    final ratio = entry.displayAspectRatio.clamp(0.5, 2.0);
    return _extent * ratio;
  }

  double _itemTotalWidth(int index) {
    if (index == _entryIndexNotifier.value && index < entryCount) {
      return _currentItemDisplayWidth(entries[index]) + _border * 2 + _sep;
    }
    return _fixedItemWidth;
  }

  double _scrollOffsetForIndex(int targetIndex) {
    double offset = _marginWidth;
    for (int i = 0; i < targetIndex; i++) {
      offset += _itemTotalWidth(i);
    }
    final targetWidth = _itemTotalWidth(targetIndex) - _sep;
    offset += targetWidth / 2;
    offset -= widget.availableWidth / 2;
    return max(0, offset);
  }

  Future<void> _goTo(int index) async {
    if (!_scrollController.hasClients) return;

    final targetOffset = _scrollOffsetForIndex(index);
    final offsetDelta = (targetOffset - _scrollController.offset).abs();

    if (offsetDelta > widget.availableWidth * 2) {
      _scrollController.jumpTo(targetOffset);
    } else {
      _isAnimating = true;
      await _scrollController.animateTo(
        targetOffset,
        duration: ADurations.thumbnailScrollerScrollAnimation,
        curve: Curves.easeOutCubic,
      );
      _isAnimating = false;
    }
  }

  void _onScrollChanged() {
    if (_isAnimating) return;
    final centerOffset = _scrollController.offset + widget.availableWidth / 2 - _marginWidth;
    final index = (centerOffset / _fixedItemWidth).round().clamp(0, entryCount - 1);
    if (_entryIndexNotifier.value != index) {
      _isScrolling = true;
      _entryIndexNotifier.value = index;
    }
  }

  void _onIndexChanged() {
    if (!_isScrolling && !_isAnimating) {
      _goTo(_entryIndexNotifier.value);
    }
    _isScrolling = false;
    if (!mounted) return;
    ShowEntryNotification(animate: false, index: _entryIndexNotifier.value).dispatch(context);
  }

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ViewerThumbnailPreview._verticalPadding),
      child: SizedBox(
        height: _extent + _border * 2,
        child: GridTheme(
          extent: _extent,
          showLocation: false,
          showTrash: false,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            controller: _scrollController,
            padding: EdgeInsets.symmetric(horizontal: _marginWidth),
            itemCount: entryCount,
            itemBuilder: (context, index) => _buildItem(index, devicePixelRatio),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(int index, double devicePixelRatio) {
    if (index < 0 || index >= entryCount) return const SizedBox();
    final entry = entries[index];

    return ValueListenableBuilder<int>(
      valueListenable: _entryIndexNotifier,
      builder: (context, currentIndex, _) {
        final isCurrent = index == currentIndex;

        if (isCurrent) {
          final width = _currentItemDisplayWidth(entry);
          return Padding(
            padding: const EdgeInsets.only(right: _sep),
            child: GestureDetector(
              onTap: () => _entryIndexNotifier.value = index,
              child: Container(
                width: width + _border * 2,
                height: _extent + _border * 2,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: _border),
                ),
                child: ThumbnailImage(
                  entry: entry,
                  extent: _extent,
                  devicePixelRatio: devicePixelRatio,
                  isMosaic: true,
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(right: _sep, top: _border, bottom: _border),
          child: GestureDetector(
            onTap: () => _entryIndexNotifier.value = index,
            child: DecoratedThumbnail(
              entry: entry,
              tileExtent: _extent,
              cancellableNotifier: _cancellableNotifier,
              selectable: false,
              highlightable: false,
            ),
          ),
        );
      },
    );
  }
}

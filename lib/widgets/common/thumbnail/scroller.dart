import 'dart:math';

import 'package:aves/model/entry/entry.dart';
import 'package:aves/theme/durations.dart';
import 'package:aves/widgets/common/behaviour/known_extent_scroll_physics.dart';
import 'package:aves/widgets/common/grid/theme.dart';
import 'package:aves/widgets/common/thumbnail/decorated.dart';
import 'package:flutter/material.dart';

class ThumbnailScroller extends StatefulWidget {
  final double availableWidth;
  final int entryCount;
  final AvesEntry? Function(int index) entryBuilder;
  final ValueNotifier<int?> indexNotifier;
  final void Function(int index)? onTap;
  final Object? Function(AvesEntry entry)? heroTagger;
  final bool scrollable, highlightable, showLocation;
  final double? extent;
  final BorderRadius? borderRadius;
  final Color? highlightBorderColor;
  final bool circular;

  const ThumbnailScroller({
    super.key,
    required this.availableWidth,
    required this.entryCount,
    required this.entryBuilder,
    required this.indexNotifier,
    this.onTap,
    this.heroTagger,
    this.highlightable = false,
    this.showLocation = true,
    this.scrollable = true,
    this.extent,
    this.borderRadius,
    this.highlightBorderColor,
    this.circular = false,
  });

  @override
  State<ThumbnailScroller> createState() => _ThumbnailScrollerState();

  static double get preferredHeight => _ThumbnailScrollerState.defaultExtent;

  static double preferredHeightFor(double extent) => extent;
}

class _ThumbnailScrollerState extends State<ThumbnailScroller> {
  final ValueNotifier<bool> _cancellableNotifier = ValueNotifier(true);
  late ScrollController _scrollController;
  bool _isAnimating = false, _isScrolling = false;

  static const double defaultExtent = 48;
  static const double separatorWidth = 2;

  double get thumbnailExtent => widget.extent ?? defaultExtent;

  double get itemExtent => thumbnailExtent + separatorWidth;

  int get entryCount => widget.entryCount;

  ValueNotifier<int?> get indexNotifier => widget.indexNotifier;

  bool get scrollable => widget.scrollable;

  double widthFor(int pageCount) => pageCount == 0 ? 0 : pageCount * thumbnailExtent + (pageCount - 1) * separatorWidth;

  @override
  void initState() {
    super.initState();
    _registerWidget(widget);
  }

  @override
  void didUpdateWidget(covariant ThumbnailScroller oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.indexNotifier != widget.indexNotifier) {
      _unregisterWidget(oldWidget);
      _registerWidget(widget);
    }
  }

  @override
  void dispose() {
    _unregisterWidget(widget);
    _cancellableNotifier.dispose();
    super.dispose();
  }

  void _registerWidget(ThumbnailScroller widget) {
    final scrollOffset = indexToScrollOffset(indexNotifier.value ?? 0);
    _scrollController = ScrollController(initialScrollOffset: scrollOffset);
    _scrollController.addListener(_onScrollChanged);
    widget.indexNotifier.addListener(_onIndexChanged);
  }

  void _unregisterWidget(ThumbnailScroller widget) {
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    widget.indexNotifier.removeListener(_onIndexChanged);
  }

  @override
  Widget build(BuildContext context) {
    final marginWidth = max(0.0, (widget.availableWidth - thumbnailExtent) / 2 - separatorWidth);
    final padding = scrollable ? EdgeInsets.only(left: marginWidth + separatorWidth, right: marginWidth) : EdgeInsets.zero;

    return GridTheme(
      extent: thumbnailExtent,
      showLocation: widget.showLocation,
      showTrash: false,
      child: SizedBox(
        width: scrollable ? null : widthFor(entryCount),
        height: thumbnailExtent,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          controller: _scrollController,
          // as of Flutter v2.10.2, `FixedExtentScrollController` can only be used with `ListWheelScrollView`
          // and `FixedExtentScrollPhysics` can only be used with Scrollables that uses the `FixedExtentScrollController`
          // so we use `KnownExtentScrollPhysics`, adapted from `FixedExtentScrollPhysics` without the constraints
          physics: scrollable
              ? KnownExtentScrollPhysics(
                  indexToScrollOffset: indexToScrollOffset,
                  scrollOffsetToIndex: scrollOffsetToIndex,
                )
              : const NeverScrollableScrollPhysics(),
          padding: padding,
          itemExtent: itemExtent,
          itemBuilder: (context, index) => _buildThumbnail(index),
          itemCount: entryCount,
        ),
      ),
    );
  }

  Widget _buildThumbnail(int index) {
    final pageEntry = widget.entryBuilder(index);
    if (pageEntry == null) return const SizedBox();

    final isCircular = widget.circular;
    final radius = widget.borderRadius ?? BorderRadius.zero;
    final highlightColor = widget.highlightBorderColor;

    Widget thumbnail = Stack(
      children: [
        GestureDetector(
          onTap: () {
            indexNotifier.value = index;
            widget.onTap?.call(index);
          },
          child: DecoratedThumbnail(
            entry: pageEntry,
            tileExtent: thumbnailExtent,
            cancellableNotifier: _cancellableNotifier,
            selectable: false,
            highlightable: widget.highlightable,
            heroTagger: () => widget.heroTagger?.call(pageEntry),
          ),
        ),
        IgnorePointer(
          child: ValueListenableBuilder<int?>(
            valueListenable: indexNotifier,
            builder: (context, currentIndex, child) {
              final isCurrent = currentIndex == index;
              final useDecoration = highlightColor != null || isCircular || radius != BorderRadius.zero;
              if (useDecoration) {
                return AnimatedContainer(
                  width: thumbnailExtent,
                  height: thumbnailExtent,
                  duration: ADurations.thumbnailScrollerShadeAnimation,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
                    borderRadius: isCircular ? null : (radius != BorderRadius.zero ? radius : null),
                    border: isCurrent && highlightColor != null ? Border.all(color: highlightColor, width: 2) : null,
                  ),
                );
              }
              return AnimatedContainer(
                color: Colors.transparent,
                width: thumbnailExtent,
                height: thumbnailExtent,
                duration: ADurations.thumbnailScrollerShadeAnimation,
              );
            },
          ),
        ),
      ],
    );

    if (isCircular) {
      thumbnail = ClipOval(child: thumbnail);
    } else if (radius != BorderRadius.zero) {
      thumbnail = ClipRRect(borderRadius: radius, child: thumbnail);
    }

    return thumbnail;
  }

  Future<void> _goTo(int index) async {
    if (!scrollable) return;

    final targetOffset = indexToScrollOffset(index);
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
    if (!_isAnimating) {
      final index = scrollOffsetToIndex(_scrollController.offset);
      if (indexNotifier.value != index) {
        _isScrolling = true;
        indexNotifier.value = index;
      }
    }
  }

  void _onIndexChanged() {
    if (!_isScrolling && !_isAnimating) {
      final index = indexNotifier.value;
      if (index != null) {
        _goTo(index);
      }
    }
    _isScrolling = false;
  }

  double indexToScrollOffset(int index) => index * itemExtent;

  int scrollOffsetToIndex(double offset) => (offset / itemExtent).round();
}

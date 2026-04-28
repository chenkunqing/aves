import 'package:aves/model/entry/entry.dart';
import 'package:aves/widgets/common/thumbnail/scroller.dart';
import 'package:aves/widgets/viewer/controls/notifications.dart';
import 'package:flutter/material.dart';

class ViewerThumbnailPreview extends StatefulWidget {
  final List<AvesEntry> entries;
  final int displayedIndex;
  final double availableWidth;

  static const double _extent = 56;
  static const double _verticalPadding = 8;

  const ViewerThumbnailPreview({
    super.key,
    required this.entries,
    required this.displayedIndex,
    required this.availableWidth,
  });

  @override
  State<ViewerThumbnailPreview> createState() => _ViewerThumbnailPreviewState();

  static double get preferredHeight => _extent + _verticalPadding * 2;
}

class _ViewerThumbnailPreviewState extends State<ViewerThumbnailPreview> {
  late final ValueNotifier<int> _entryIndexNotifier;

  List<AvesEntry> get entries => widget.entries;

  int get entryCount => entries.length;

  @override
  void initState() {
    super.initState();
    _entryIndexNotifier = ValueNotifier(widget.displayedIndex);
    _entryIndexNotifier.addListener(_onScrollerIndexChanged);
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
    _entryIndexNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: Container(
        color: Colors.black54,
        padding: const EdgeInsets.symmetric(vertical: ViewerThumbnailPreview._verticalPadding),
        child: ThumbnailScroller(
          availableWidth: widget.availableWidth,
          entryCount: entryCount,
          entryBuilder: (index) => 0 <= index && index < entryCount ? entries[index] : null,
          indexNotifier: _entryIndexNotifier,
          onTap: (index) => ShowEntryNotification(animate: false, index: index).dispatch(context),
          extent: ViewerThumbnailPreview._extent,
          borderRadius: BorderRadius.circular(4),
          highlightBorderColor: Colors.white,
        ),
      ),
    );
  }

  void _onScrollerIndexChanged() {
    if (!mounted) return;
    ShowEntryNotification(animate: false, index: _entryIndexNotifier.value).dispatch(context);
  }
}

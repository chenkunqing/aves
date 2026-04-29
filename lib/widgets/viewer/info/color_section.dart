import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/entry/extensions/images.dart';
import 'package:aves/model/entry_colors.dart';
import 'package:aves/model/filters/color.dart';
import 'package:aves/model/source/collection_lens.dart';
import 'package:aves/theme/durations.dart';
import 'package:aves/theme/icons.dart';
import 'package:aves/widgets/common/basic/color_indicator.dart';
import 'package:aves/widgets/common/identity/aves_filter_chip.dart';
import 'package:aves/widgets/viewer/info/common.dart';
import 'package:aves_utils/aves_utils.dart';
import 'package:flex_color_picker/flex_color_picker.dart' as flex;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:provider/provider.dart';

class ColorSectionSliver extends StatefulWidget {
  final AvesEntry entry;
  final CollectionLens? collection;
  final AFilterCallback? onFilterSelection;

  const ColorSectionSliver({
    super.key,
    required this.entry,
    this.collection,
    this.onFilterSelection,
  });

  @override
  State<ColorSectionSliver> createState() => _ColorSectionSliverState();
}

class _ColorSectionSliverState extends State<ColorSectionSliver> {
  late final Future<List<Color>> _paletteLoader;

  @override
  void initState() {
    super.initState();
    final provider = widget.entry.getThumbnail(extent: min(200, widget.entry.displaySize.longestSide));
    _paletteLoader = _loadPalette(provider);
  }

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: FutureBuilder<List<Color>>(
        future: _paletteLoader,
        builder: (context, snapshot) {
          final colors = snapshot.data;
          if (colors == null || colors.isEmpty) return const SizedBox();

          final durations = context.watch<DurationsData>();
          return Wrap(
            alignment: WrapAlignment.center,
            children: AnimationConfiguration.toStaggeredList(
              duration: durations.staggeredAnimation,
              delay: durations.staggeredAnimationDelay * timeDilation,
              childAnimationBuilder: (child) => SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  child: child,
                ),
              ),
              children: [
                const SectionRow(icon: AIcons.palette),
                ...colors.map(
                  (v) => _buildColorItem(context, v),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildColorItem(BuildContext context, Color color) {
    final child = Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ColorIndicator(value: color),
          const SizedBox(width: 8),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              '#${color.hex}',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );

    if (widget.onFilterSelection == null) return child;

    return GestureDetector(
      onTap: () => _onColorTap(color),
      child: child,
    );
  }

  Future<void> _onColorTap(Color color) async {
    final collection = widget.collection;
    if (collection == null) return;

    final source = collection.source;
    final allEntries = source.visibleEntries;
    final unindexed = allEntries.where((e) => !entryColors.isIndexed(e.id)).toList();

    if (unindexed.isNotEmpty) {
      final success = await _buildIndex(context, unindexed);
      if (!success || !mounted) return;
    }

    widget.onFilterSelection?.call(ColorFilter(color.toARGB32()));
  }

  Future<bool> _buildIndex(BuildContext context, List<AvesEntry> entries) async {
    final total = entries.length;
    final progressNotifier = ValueNotifier<int>(0);

    unawaited(
      _indexEntries(entries, (count) {
        progressNotifier.value = count;
      }).then((_) {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop(true);
        }
      }),
    );

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('扫描照片色彩'),
            content: ValueListenableBuilder<int>(
              valueListenable: progressNotifier,
              builder: (context, indexed, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: total > 0 ? indexed / total : 0),
                  const SizedBox(height: 8),
                  Text('$indexed / $total'),
                ],
              ),
            ),
          ),
        );
      },
    );
    progressNotifier.dispose();
    return result == true;
  }

  static Future<void> _indexEntries(
    List<AvesEntry> entries,
    void Function(int count) onProgress,
  ) async {
    var count = 0;
    for (final entry in entries) {
      try {
        final provider = entry.getThumbnail(extent: min(200, entry.displaySize.longestSide));
        final colors = await _loadPaletteStatic(provider);
        await entryColors.save(entry.id, colors);
      } catch (e) {
        debugPrint('Failed to index colors for entry ${entry.id}: $e');
      }
      count++;
      if (count % 5 == 0 || count == entries.length) {
        onProgress(count);
      }
    }
  }

  Future<List<Color>> _loadPalette(ImageProvider provider) async {
    final colors = await _loadPaletteStatic(provider);
    if (colors.isNotEmpty) {
      unawaited(entryColors.save(widget.entry.id, colors));
    }
    return colors;
  }

  static Future<List<Color>> _loadPaletteStatic(ImageProvider provider) async {
    final stream = provider.resolve(ImageConfiguration.empty);
    final imageInfoCompleter = Completer<ImageInfo>();
    late ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      stream.removeListener(listener);
      imageInfoCompleter.complete(info);
    });

    stream.addListener(listener);
    final imageInfo = await imageInfoCompleter.future;
    final imageData = await imageInfo.image.toByteData();
    imageInfo.dispose();

    if (imageData == null) {
      throw StateError('Failed to encode the image.');
    }

    return await _extractColors(imageData);
  }

  static Future<List<Color>> _extractColors(ByteData encodedImage) {
    return Isolate.run(
      () => ColorExtractor.extract(
        imageBytes: encodedImage,
        maximumColorCount: 10,
      ),
    );
  }
}

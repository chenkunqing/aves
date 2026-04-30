import 'dart:async';
import 'dart:math';

import 'package:aves/app_mode.dart';
import 'package:aves/image_providers/app_icon_image_provider.dart';
import 'package:aves/model/app_inventory.dart';
import 'package:aves/model/dynamic_albums.dart';
import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/entry/extensions/favourites.dart';
import 'package:aves/model/entry/extensions/multipage.dart';
import 'package:aves/model/entry/extensions/props.dart';
import 'package:aves/model/favourites.dart';
import 'package:aves/model/filters/aspect_ratio.dart';
import 'package:aves/model/filters/covered/stored_album.dart';
import 'package:aves/model/filters/covered/tag.dart';
import 'package:aves/model/entry_faces.dart';
import 'package:aves/model/filters/date.dart';
import 'package:aves/model/filters/face_count.dart';
import 'package:aves/services/face_detection_service.dart';
import 'package:aves/model/filters/favourite.dart';
import 'package:aves/model/filters/mime.dart';
import 'package:aves/model/filters/type.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/model/source/collection_lens.dart';
import 'package:aves/ref/mime_types.dart';
import 'package:aves/services/common/services.dart';
import 'package:aves/theme/colors.dart';
import 'package:aves/theme/format.dart';
import 'package:aves/utils/file_utils.dart';
import 'package:aves/utils/time_utils.dart';
import 'package:aves/view/view.dart';
import 'package:aves/widgets/common/action_controls/quick_choosers/tag_button.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:aves/widgets/common/identity/aves_filter_chip.dart';
import 'package:aves/widgets/viewer/action/entry_info_action_delegate.dart';
import 'package:aves/widgets/viewer/info/common.dart';
import 'package:aves_model/aves_model.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class BasicSection extends StatefulWidget {
  final AvesEntry entry;
  final CollectionLens? collection;
  final EntryInfoActionDelegate actionDelegate;
  final ValueNotifier<bool> isScrollingNotifier;
  final ValueNotifier<EntryAction?> isEditingMetadataNotifier;
  final AFilterCallback onFilterSelection;

  const BasicSection({
    super.key,
    required this.entry,
    this.collection,
    required this.actionDelegate,
    required this.isScrollingNotifier,
    required this.isEditingMetadataNotifier,
    required this.onFilterSelection,
  });

  @override
  State<BasicSection> createState() => _BasicSectionState();
}

class _BasicSectionState extends State<BasicSection> with AutomaticKeepAliveClientMixin {
  static final _commonRatioFilters = [
    AspectRatioFilter.ratio1x1,
    AspectRatioFilter.ratio4x3,
    AspectRatioFilter.ratio3x4,
    AspectRatioFilter.ratio16x9,
    AspectRatioFilter.ratio9x16,
    AspectRatioFilter.ratio27x10,
  ];

  final FocusNode _chipFocusNode = FocusNode();

  CollectionLens? get collection => widget.collection;

  EntryInfoActionDelegate get actionDelegate => widget.actionDelegate;

  @override
  void initState() {
    super.initState();
    _registerWidget(widget);
    _onScrollingChanged();
  }

  @override
  void didUpdateWidget(covariant BasicSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _unregisterWidget(oldWidget);
    _registerWidget(widget);
  }

  @override
  void dispose() {
    _unregisterWidget(widget);
    _chipFocusNode.dispose();
    super.dispose();
  }

  void _registerWidget(BasicSection widget) {
    widget.isScrollingNotifier.addListener(_onScrollingChanged);
  }

  void _unregisterWidget(BasicSection widget) {
    widget.isScrollingNotifier.removeListener(_onScrollingChanged);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final entry = widget.entry;
    return AnimatedBuilder(
      animation: entry.metadataChangeNotifier,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BasicInfo(entry: entry),
            Focus(
              focusNode: _chipFocusNode,
              skipTraversal: true,
              canRequestFocus: false,
              child: _buildChips(context),
            ),
            _buildEditButtons(context),
          ],
        );
      },
    );
  }

  Widget _buildChips(BuildContext context) {
    final entry = widget.entry;
    final tags = entry.tags.toList()..sort(compareAsciiUpperCaseNatural);
    final dateTime = entry.bestDate;
    final album = entry.directory;
    final filters = {
      MimeFilter(entry.mimeType),
      if (entry.isAnimated) TypeFilter.animated,
      if (entry.isGeotiff) TypeFilter.geotiff,
      if (entry.isHdr) TypeFilter.hdr,
      if (entry.isMotionPhoto) TypeFilter.motionPhoto,
      if (entry.isRaw) TypeFilter.raw,
      if (entry.isImage && entry.is360) TypeFilter.panorama,
      if (entry.isPureVideo && entry.is360) TypeFilter.sphericalVideo,
      if (entry.isPureVideo && !entry.is360) MimeFilter.video,
      if (entry.isSized) ..._commonRatioFilters.where((f) => f.test(entry)),
      if (dateTime != null) DateFilter(DateLevel.ymd, dateTime.date),
      if (album != null) StoredAlbumFilter(album, collection?.source.getStoredAlbumDisplayName(context, album)),
      ...dynamicAlbums.all.where((v) => !v.isBuiltIn && v.test(entry)).toSet(),
      ...tags.map(TagFilter.new),
      if (entryFaces.isTwoPersonPhoto(entry.id)) FaceCountFilter.twoPerson(),
      if (entryFaces.isMultiPersonPhoto(entry.id)) FaceCountFilter.multiPerson(),
    };
    return AnimatedBuilder(
      animation: favourites,
      builder: (context, child) {
        final effectiveFilters = [
          ...filters,
          if (entry.isFavourite) FavouriteFilter.instance,
        ]..sort();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AvesFilterChip.outlineWidth / 2) + const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...effectiveFilters.map(
                (filter) => AvesFilterChip(
                  filter: filter,
                  onTap: widget.onFilterSelection,
                ),
              ),
              if (entry.isImage && kDebugMode)
                _FaceDebugButton(entry: entry),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEditButtons(BuildContext context) {
    final appMode = context.watch<ValueNotifier<AppMode>>().value;
    final entry = widget.entry;
    final children =
        [
              EntryAction.editTags,
            ]
            .where(
              (v) => actionDelegate.isVisible(
                appMode: appMode,
                targetEntry: entry,
                action: v,
              ),
            )
            .where((v) => actionDelegate.canApply(entry, v))
            .map((v) => _buildEditMetadataButton(context, v))
            .toList();

    return children.isEmpty
        ? const SizedBox()
        : TooltipTheme(
            data: TooltipTheme.of(context).copyWith(
              preferBelow: false,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AvesFilterChip.outlineWidth / 2) + const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: children,
              ),
            ),
          );
  }

  Widget _buildEditMetadataButton(BuildContext context, EntryAction action) {
    final entry = widget.entry;
    return ValueListenableBuilder<EntryAction?>(
      valueListenable: widget.isEditingMetadataNotifier,
      builder: (context, editingAction, child) {
        final isEditing = editingAction != null;
        final onPressed = isEditing ? null : () => actionDelegate.onActionSelected(context, entry, collection, action);
        Widget button;
        switch (action) {
          case .editTags:
            button = TagButton(
              blurred: false,
              onChooserValue: (filter) => actionDelegate.quickTag(context, entry, filter),
              onPressed: onPressed,
            );
          default:
            button = IconButton(
              icon: action.getIcon(),
              onPressed: onPressed,
              tooltip: action.getText(context),
            );
        }
        return Stack(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.fromBorderSide(
                  BorderSide(
                    color: isEditing ? Theme.of(context).disabledColor : context.select<AvesColorsData, Color>((v) => v.neutral),
                    width: AvesFilterChip.outlineWidth,
                  ),
                ),
                borderRadius: const BorderRadius.all(Radius.circular(AvesFilterChip.defaultRadius)),
              ),
              child: button,
            ),
            Positioned.fill(
              child: Visibility(
                visible: editingAction == action,
                child: const Padding(
                  padding: EdgeInsets.all(1.0),
                  child: CircularProgressIndicator(
                    strokeWidth: AvesFilterChip.outlineWidth,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _onScrollingChanged() {
    if (!widget.isScrollingNotifier.value) {
      if (settings.useTvLayout) {
        // using `autofocus` while scrolling seems to fail for widget built offscreen
        // so we give focus to this page when the screen is no longer scrolling
        _chipFocusNode.children.firstOrNull?.requestFocus();
      }
    }
  }

  @override
  bool get wantKeepAlive => true;
}

class _BasicInfo extends StatefulWidget {
  final AvesEntry entry;

  const _BasicInfo({
    required this.entry,
  });

  @override
  State<_BasicInfo> createState() => _BasicInfoState();
}

class _BasicInfoState extends State<_BasicInfo> {
  static const _standardPrintSizes = [
    _PrintSizePreset(labelEn: '5"', labelZh: '5\u5bf8', widthInches: 5, heightInches: 3.5),
    _PrintSizePreset(labelEn: '6"', labelZh: '6\u5bf8', widthInches: 6, heightInches: 4),
    _PrintSizePreset(labelEn: '7"', labelZh: '7\u5bf8', widthInches: 7, heightInches: 5),
    _PrintSizePreset(labelEn: '8"', labelZh: '8\u5bf8', widthInches: 8, heightInches: 6),
    _PrintSizePreset(labelEn: '10"', labelZh: '10\u5bf8', widthInches: 10, heightInches: 8),
    _PrintSizePreset(labelEn: '12"', labelZh: '12\u5bf8', widthInches: 12, heightInches: 10),
  ];

  Future<String?> _ownerPackageLoader = SynchronousFuture(null);
  Future<void> _appNameLoader = SynchronousFuture(null);

  AvesEntry get entry => widget.entry;

  static const ownerPackageNamePropKey = 'owner_package_name';
  static const iconSize = 20.0;

  @override
  void initState() {
    super.initState();
    if (!entry.trashed && entry.isMediaStoreMediaContent) {
      _ownerPackageLoader = metadataFetchService.hasContentResolverProp(ownerPackageNamePropKey).then((exists) {
        return exists ? metadataFetchService.getContentResolverProp(entry, ownerPackageNamePropKey) : SynchronousFuture(null);
      });
      final isViewerMode = context.read<ValueNotifier<AppMode>>().value == AppMode.view;
      if (isViewerMode && settings.isInstalledAppAccessAllowed) {
        _appNameLoader = appInventory.initAppNames();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final infoUnknown = l10n.viewerInfoUnknown;
    final locale = context.locale;
    final use24hour = MediaQuery.alwaysUse24HourFormatOf(context);

    // TODO TLAD line break on all characters for the following fields when this is fixed: https://github.com/flutter/flutter/issues/61081
    // inserting ZWSP (\u200B) between characters does help, but it messes with width and height computation (another Flutter issue)
    final title = entry.bestTitle ?? infoUnknown;
    final date = entry.bestDate;
    final dateText = date != null ? formatDateTime(date, locale, use24hour) : infoUnknown;
    final showResolution = !entry.isSvg && entry.isSized;
    final printSizeLines = _getPrintSizeLines(context);
    final sizeText = entry.sizeBytes != null ? formatFileSize(locale, entry.sizeBytes!) : infoUnknown;
    final path = entry.path;

    return FutureBuilder<String?>(
      future: _ownerPackageLoader,
      builder: (context, snapshot) {
        final ownerPackage = snapshot.data;
        return FutureBuilder<void>(
          future: _appNameLoader,
          builder: (context, snapshot) {
            return InfoRowGroup(
              info: {
                l10n.viewerInfoLabelTitle: title,
                l10n.viewerInfoLabelDate: dateText,
                if (entry.isVideo) ..._buildVideoRows(context),
                if (showResolution) l10n.viewerInfoLabelResolution: context.applyDirectionality(getRasterResolutionText(locale)),
                if (printSizeLines != null) _printSizeLabel(context): context.applyDirectionality(printSizeLines.$1),
                if (printSizeLines?.$2 != null) '': context.applyDirectionality(printSizeLines!.$2!),
                l10n.viewerInfoLabelSize: context.applyDirectionality(sizeText),
                if (!entry.trashed) l10n.viewerInfoLabelUri: entry.uri,
                l10n.viewerInfoLabelPath: ?path,
                l10n.viewerInfoLabelOwner: ?ownerPackage,
              },
              spanBuilders: {
                l10n.viewerInfoLabelOwner: _ownerHandler(ownerPackage),
              },
            );
          },
        );
      },
    );
  }

  Map<String, String> _buildVideoRows(BuildContext context) {
    return {
      context.l10n.viewerInfoLabelDuration: entry.durationText,
    };
  }

  static const _hdDpi = 300.0;
  static const _clearDpi = 200.0;

  (String, String?)? _getPrintSizeLines(BuildContext context) {
    if (!entry.isImage || !entry.isSized || entry.isSvg) return null;

    final sizeAt300 = entry.maxPrintSizeAtDpiInches(_hdDpi);
    final sizeAt200 = entry.maxPrintSizeAtDpiInches(_clearDpi);
    if (sizeAt200.width <= 0 || sizeAt200.height <= 0) return null;

    final hdPreset = _getBestPrintSizePreset(sizeAt300);
    final clearPreset = _getBestPrintSizePreset(sizeAt200);
    final isChinese = context.locale.startsWith('zh');

    if (hdPreset == null && clearPreset == null) {
      final text = isChinese ? '\u4e0d\u5efa\u8bae\u6253\u5370\uff08\u5206\u8fa8\u7387\u4e0d\u8db3\uff09' : 'Not recommended for printing (low resolution)';
      return (text, null);
    }

    String? hdLine;
    String? clearLine;

    if (hdPreset != null) {
      hdLine = isChinese
          ? '\u9002\u5408\u6253\u5370${hdPreset.labelZh}\u7167\u7247\uff08\u9ad8\u6e05\uff09'
          : 'Suitable for ${hdPreset.labelEn} prints (HD)';
    }
    if (clearPreset != null && clearPreset != hdPreset) {
      clearLine = isChinese
          ? '\u6700\u5927\u53ef\u6253\u5370${clearPreset.labelZh}\u7167\u7247\uff08\u753b\u8d28\u6e05\u6670\uff09'
          : 'Max ${clearPreset.labelEn} prints (clear quality)';
    }

    if (hdLine != null) return (hdLine, clearLine);
    if (clearLine != null) return (clearLine, null);
    return null;
  }

  _PrintSizePreset? _getBestPrintSizePreset(Size sizeInches) {
    final longSide = max(sizeInches.width, sizeInches.height);
    final shortSide = min(sizeInches.width, sizeInches.height);
    return _standardPrintSizes.reversed.firstWhereOrNull((preset) => longSide >= preset.longSide && shortSide >= preset.shortSide);
  }

  String _printSizeLabel(BuildContext context) {
    return context.locale.startsWith('zh') ? '\u5efa\u8bae\u6253\u5370\u5c3a\u5bf8' : 'Recommended print size';
  }

  InfoValueSpanBuilder _ownerHandler(String? ownerPackage) {
    if (ownerPackage == null) return (context, key, value) => [];

    final appName = appInventory.getCurrentAppName(ownerPackage) ?? ownerPackage;
    return (context, key, value) => [
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 2, end: 4),
          child: ConstrainedBox(
            // use constraints instead of sizing `Image`,
            // so that it can collapse when handling an empty image
            constraints: const BoxConstraints(
              maxWidth: iconSize,
              maxHeight: iconSize,
            ),
            child: Image(
              image: AppIconImage(
                packageName: ownerPackage,
                size: iconSize,
              ),
            ),
          ),
        ),
      ),
      TextSpan(
        text: appName,
        style: InfoRowGroup.valueStyle,
      ),
    ];
  }

  String getRasterResolutionText(String locale) {
    var s = entry.getResolutionText(locale);

    // guess whether this is a photo, according to file type
    final isPhoto = [MimeTypes.heic, MimeTypes.heif, MimeTypes.jpeg, MimeTypes.tiff].contains(entry.mimeType) || entry.isRaw;
    if (isPhoto) {
      final megaPixels = (entry.width * entry.height / 1000000).round();
      if (megaPixels > 0) {
        s += ' • ${NumberFormat('0', locale).format(megaPixels)} MP';
      }
    }

    return s;
  }
}

class _PrintSizePreset {
  final String labelEn;
  final String labelZh;
  final double widthInches;
  final double heightInches;

  const _PrintSizePreset({
    required this.labelEn,
    required this.labelZh,
    required this.widthInches,
    required this.heightInches,
  });

  double get longSide => max(widthInches, heightInches);

  double get shortSide => min(widthInches, heightInches);
}

class _FaceDebugButton extends StatelessWidget {
  final AvesEntry entry;

  const _FaceDebugButton({required this.entry});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _runDebug(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bug_report, size: 16, color: Theme.of(context).colorScheme.onSurface),
            const SizedBox(width: 4),
            Text('Face: ${entryFaces.getFaceCount(entry.id) ?? "?"}',
                style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Future<void> _runDebug(BuildContext context) async {
    final navigator = Navigator.of(context);

    unawaited(showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    ));

    String info;
    try {
      final oldCount = entryFaces.getFaceCount(entry.id);
      final result = await faceDetectionService.detectFaces(
        uri: entry.uri,
        mimeType: entry.mimeType,
        rotationDegrees: entry.rotationDegrees,
        width: entry.width,
        height: entry.height,
      );
      await entryFaces.save(entry.id, result.faceCount, result.boundingBoxes);
      info = '原始URI: ${entry.uri}\n'
          '尺寸: ${entry.width}x${entry.height}\n'
          '旧faceCount: ${oldCount ?? "未扫描"} → 新faceCount: ${result.faceCount}\n'
          '---\n'
          '${result.debugInfo ?? "无调试信息"}\n'
          '---\n'
          '已更新数据库';
    } catch (e) {
      info = '检测失败: $e';
    }

    navigator.pop();
    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('人脸检测调试'),
        content: SingleChildScrollView(
          child: SelectableText(info, style: const TextStyle(fontSize: 12)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

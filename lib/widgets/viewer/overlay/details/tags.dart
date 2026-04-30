import 'package:aves/model/entry/entry.dart';
import 'package:aves/theme/icons.dart';
import 'package:aves/theme/text.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:aves/widgets/viewer/overlay/details/details.dart';
import 'package:collection/collection.dart';
import 'package:decorated_icon/decorated_icon.dart';
import 'package:flutter/material.dart';

class OverlayTagsRow extends AnimatedWidget {
  final AvesEntry entry;

  OverlayTagsRow({
    super.key,
    required this.entry,
  }) : super(listenable: entry.metadataChangeNotifier);

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final tags = entry.tags.toList()..sort(compareAsciiUpperCaseNatural);

    const iconSize = ViewerDetailOverlayContent.iconSize;
    final textScaleFactor = textScaler.scale(iconSize) / iconSize;

    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: ViewerDetailOverlayContent.iconPadding),
              child: DecoratedIcon(
                AIcons.tag,
                size: iconSize / textScaleFactor,
                shadows: ViewerDetailOverlayContent.shadows(context),
              ),
            ),
          ),
          TextSpan(text: tags.join(AText.separator)),
        ],
      ),
    );
  }
}
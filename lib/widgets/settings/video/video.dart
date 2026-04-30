import 'dart:async';

import 'package:aves/model/filters/mime.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/theme/colors.dart';
import 'package:aves/theme/icons.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:aves/widgets/settings/common/tile_leading.dart';
import 'package:aves/widgets/settings/common/tiles.dart';
import 'package:aves/widgets/settings/settings_definition.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class VideoSection extends SettingsSection {
  VideoSection();

  @override
  String get key => 'video';

  @override
  Widget icon(BuildContext context) => SettingsTileLeading(
    icon: AIcons.video,
    color: context.select<AvesColorsData, Color>((v) => v.video),
  );

  @override
  String title(BuildContext context) => context.l10n.settingsVideoSectionTitle;

  @override
  Future<List<SettingsTile>> tiles(BuildContext context) async {
    return [
      SettingsTileVideoShowVideos(),
    ];
  }
}

class SettingsTileVideoShowVideos extends SettingsTile {
  @override
  String title(BuildContext context) => context.l10n.settingsVideoShowVideos;

  @override
  Widget build(BuildContext context) => SettingsSwitchListTile(
    selector: (context, s) => !s.hiddenFilters.contains(MimeFilter.video),
    onChanged: (v) => settings.changeFilterVisibility({MimeFilter.video}, v),
    title: title(context),
  );
}

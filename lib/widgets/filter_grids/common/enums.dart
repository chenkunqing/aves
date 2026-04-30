import 'package:aves/theme/icons.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:flutter/material.dart';

enum ChipType { regular, group }

enum AlbumChipType { stored, dynamic, group }

enum AlbumImportance { newAlbum, pinned, group, special, apps, dynamic, regular }

extension ExtraAlbumImportance on AlbumImportance {
  String getText(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      AlbumImportance.newAlbum => l10n.albumTierNew,
      AlbumImportance.pinned => l10n.albumTierPinned,
      AlbumImportance.group => l10n.albumTierGroups,
      AlbumImportance.special => l10n.albumTierSpecial,
      AlbumImportance.apps => l10n.albumTierApps,
      AlbumImportance.dynamic => l10n.albumTierDynamic,
      AlbumImportance.regular => l10n.albumTierRegular,
    };
  }

  IconData getIcon() {
    return switch (this) {
      AlbumImportance.newAlbum => AIcons.newTier,
      AlbumImportance.pinned => AIcons.pin,
      AlbumImportance.group => AIcons.group,
      AlbumImportance.special => AIcons.important,
      AlbumImportance.apps => AIcons.app,
      AlbumImportance.dynamic => AIcons.dynamicAlbum,
      AlbumImportance.regular => AIcons.album,
    };
  }
}

enum AlbumMimeType { images, videos, mixed }

extension ExtraAlbumMimeType on AlbumMimeType {
  String getText(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      AlbumMimeType.images => l10n.drawerCollectionImages,
      AlbumMimeType.videos => l10n.drawerCollectionVideos,
      AlbumMimeType.mixed => l10n.albumMimeTypeMixed,
    };
  }

  IconData getIcon() {
    return switch (this) {
      AlbumMimeType.images => AIcons.image,
      AlbumMimeType.videos => AIcons.video,
      AlbumMimeType.mixed => AIcons.mimeType,
    };
  }
}

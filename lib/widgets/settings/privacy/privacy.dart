import 'dart:async';

import 'package:aves/app_flavor.dart';
import 'package:aves/model/device.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/model/source/collection_source.dart';
import 'package:aves/model/vaults/vaults.dart';
import 'package:aves/services/common/services.dart';
import 'package:aves/theme/colors.dart';
import 'package:aves/theme/durations.dart';
import 'package:aves/theme/icons.dart';
import 'package:aves/widgets/collection/entry_set_action_delegate.dart';
import 'package:aves/widgets/common/action_mixins/permission_aware.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:aves/widgets/dialogs/aves_confirmation_dialog.dart';
import 'package:aves/widgets/dialogs/aves_dialog.dart';
import 'package:aves/widgets/settings/common/tile_leading.dart';
import 'package:aves/widgets/settings/common/tiles.dart';
import 'package:aves/widgets/settings/privacy/access_grants_page.dart';
import 'package:aves/widgets/settings/privacy/hidden_items_page.dart';
import 'package:aves/widgets/settings/settings_definition.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PrivacySection extends SettingsSection {
  @override
  String get key => 'privacy';

  @override
  Widget icon(BuildContext context) => SettingsTileLeading(
    icon: AIcons.privacy,
    color: context.select<AvesColorsData, Color>((v) => v.privacy),
  );

  @override
  String title(BuildContext context) => context.l10n.settingsPrivacySectionTitle;

  @override
  Future<List<SettingsTile>> tiles(BuildContext context) async {
    final canEnableErrorReporting = context.select<AppFlavor, bool>((v) => v.canEnableErrorReporting);
    return [
      SettingsTilePrivacyAllowInstalledAppAccess(),
      if (canEnableErrorReporting) SettingsTilePrivacyAllowErrorReporting(),
      if (!settings.useTvLayout && device.canRequestManageMedia) SettingsTilePrivacyManageMedia(),
      if (!settings.useTvLayout) SettingsTilePrivacyAutoExportSettings(),
      SettingsTilePrivacySaveSearchHistory(),
      if (!settings.useTvLayout) SettingsTilePrivacyEnableBin(),
      SettingsTilePrivacyHiddenItems(),
      if (!settings.useTvLayout) SettingsTilePrivacyStorageAccess(),
    ];
  }
}

class SettingsTilePrivacyAllowInstalledAppAccess extends SettingsTile {
  @override
  String title(BuildContext context) => context.l10n.settingsAllowInstalledAppAccess;

  @override
  Widget build(BuildContext context) => SettingsSwitchListTile(
    selector: (context, s) => s.isInstalledAppAccessAllowed,
    onChanged: (v) => settings.isInstalledAppAccessAllowed = v,
    leading: const Icon(AIcons.app),
    title: title,
    subtitle: (context) => context.l10n.settingsAllowInstalledAppAccessSubtitle,
  );
}

class SettingsTilePrivacyAllowErrorReporting extends SettingsTile {
  @override
  String title(BuildContext context) => context.l10n.settingsAllowErrorReporting;

  @override
  Widget build(BuildContext context) => SettingsSwitchListTile(
    selector: (context, s) => s.isErrorReportingAllowed,
    onChanged: (v) => settings.isErrorReportingAllowed = v,
    leading: const Icon(AIcons.bugReport),
    title: title,
  );
}

class SettingsTilePrivacyAutoExportSettings extends SettingsTile with PermissionAwareMixin {
  @override
  String title(BuildContext context) => context.l10n.settingsAutoExportSettings;

  @override
  Widget build(BuildContext context) => SettingsSwitchListTile(
    selector: (context, s) => s.autoExportPath != null,
    onChanged: (v) async {
      if (v) {
        if (!await checkSystemFilePickerEnabled(context)) return;

        final dirPath = await storageService.requestAnyDirectoryAccess();
        if (dirPath == null) return;

        settings.autoExportPath = dirPath;
      } else {
        settings.autoExportPath = null;
      }
    },
    leading: const Icon(AIcons.fileExport),
    title: title,
    subtitle: (_) => settings.autoExportPath,
  );
}

class SettingsTilePrivacySaveSearchHistory extends SettingsTile {
  @override
  String title(BuildContext context) => context.l10n.settingsSaveSearchHistory;

  @override
  Widget build(BuildContext context) => SettingsSwitchListTile(
    selector: (context, s) => s.saveSearchHistory,
    onChanged: (v) {
      settings.saveSearchHistory = v;
      if (!v) {
        settings.searchHistory = [];
      }
    },
    leading: const Icon(AIcons.searchHistory),
    title: title,
  );
}

class SettingsTilePrivacyEnableBin extends SettingsTile {
  @override
  String title(BuildContext context) => context.l10n.settingsEnableBin;

  @override
  Widget build(BuildContext context) => SettingsSwitchListTile(
    selector: (context, s) => s.enableBin,
    onChanged: (v) => setBinUsage(context, v),
    leading: const Icon(AIcons.bin),
    title: title,
    subtitle: (context) => context.l10n.settingsEnableBinSubtitle,
  );

  static Future<bool> setBinUsage(BuildContext context, bool enabled) async {
    final l10n = context.l10n;
    if (!enabled) {
      if (vaults.all.any((v) => v.useBin)) {
        await showWarningDialog(
          context: context,
          message: l10n.vaultBinUsageDialogMessage,
        );
        return false;
      }

      final source = context.read<CollectionSource>();
      final trashedEntries = source.trashedEntries;
      if (trashedEntries.isNotEmpty) {
        if (!await showConfirmationDialog(
          context: context,
          message: l10n.settingsDisablingBinWarningDialogMessage,
          ok: l10n.applyButtonLabel,
        )) {
          return false;
        }

        // delete forever trashed items
        await EntrySetActionDelegate().doDelete(
          context: context,
          entries: trashedEntries,
          enableBin: false,
        );

        // in case of failure or cancellation
        if (source.trashedEntries.isNotEmpty) return false;
      }

      settings.searchHistory = [];
    }

    settings.enableBin = enabled;
    return true;
  }
}

class SettingsTilePrivacyHiddenItems extends SettingsTile {
  @override
  String title(BuildContext context) => context.l10n.settingsHiddenItemsTile;

  @override
  Widget build(BuildContext context) => SettingsSubPageTile(
    title: title,
    routeName: HiddenItemsPage.routeName,
    builder: (context) => const HiddenItemsPage(),
  );
}

class SettingsTilePrivacyStorageAccess extends SettingsTile {
  @override
  String title(BuildContext context) => context.l10n.settingsStorageAccessTile;

  @override
  Widget build(BuildContext context) => SettingsSubPageTile(
    title: title,
    routeName: StorageAccessPage.routeName,
    builder: (context) => const StorageAccessPage(),
  );
}

class SettingsTilePrivacyManageMedia extends SettingsTile {
  @override
  String title(BuildContext context) => context.l10n.settingsAllowMediaManagement;

  @override
  Widget build(BuildContext context) => _ManageMediaTile(title: title(context));
}

class _ManageMediaTile extends StatefulWidget {
  final String title;

  const _ManageMediaTile({
    required this.title,
  });

  @override
  State<_ManageMediaTile> createState() => _ManageMediaTileState();
}

class _ManageMediaTileState extends State<_ManageMediaTile> with WidgetsBindingObserver {
  late Future<bool> _loader;

  @override
  void initState() {
    super.initState();
    _initLoader();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _initLoader() => _loader = deviceService.canManageMedia();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initLoader();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _loader,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState != ConnectionState.done;
        final current = snapshot.data ?? false;

        final onChanged = loading ? null : (v) => deviceService.requestMediaManagePermission();
        final leading = AnimatedOpacity(
          opacity: current && onChanged != null ? 1 : SettingsSwitchListTile.disabledOpacity,
          duration: ADurations.toggleableTransitionLoose,
          child: const Icon(AIcons.allCollection),
        );

        return SwitchListTile(
          value: current,
          onChanged: onChanged,
          title: Text(widget.title),
          secondary: leading,
        );
      },
    );
  }
}

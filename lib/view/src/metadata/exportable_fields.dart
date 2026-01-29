import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:aves_model/aves_model.dart';
import 'package:flutter/widgets.dart';

extension ExtraExportableEntryFields on ExportableEntryField {
  String getText(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      ExportableEntryField.uri => l10n.viewerInfoLabelUri,
      ExportableEntryField.path => l10n.viewerInfoLabelPath,
      ExportableEntryField.date => l10n.viewerInfoLabelDate,
      ExportableEntryField.size => l10n.viewerInfoLabelSize,
      ExportableEntryField.width => l10n.exportEntryDialogWidth,
      ExportableEntryField.height => l10n.exportEntryDialogHeight,
      ExportableEntryField.duration => l10n.viewerInfoLabelDuration,
      ExportableEntryField.coordinates => l10n.viewerInfoLabelCoordinates,
      ExportableEntryField.address => l10n.viewerInfoLabelAddress,
    };
  }
}

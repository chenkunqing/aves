import 'package:aves/ref/mime_types.dart';
import 'package:aves/theme/themes.dart';
import 'package:aves/utils/mime_utils.dart';
import 'package:aves/view/src/metadata/exportable_fields.dart';
import 'package:aves/widgets/common/basic/text/outlined.dart';
import 'package:aves/widgets/common/basic/text_dropdown_button.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:aves/widgets/common/identity/highlight_title.dart';
import 'package:aves/widgets/dialogs/aves_dialog.dart';
import 'package:aves_model/aves_model.dart';
import 'package:flutter/material.dart';

class ExportCollectionStatsDialog extends StatefulWidget {
  static const routeName = '/dialog/export_collection_stats';

  const ExportCollectionStatsDialog({super.key});

  @override
  State<ExportCollectionStatsDialog> createState() => _ExportCollectionStatsDialogState();
}

class _ExportCollectionStatsDialogState extends State<ExportCollectionStatsDialog> {
  static const List<ExportableEntryField> _entryFieldOptions = ExportableEntryField.values;
  final Set<ExportableEntryField> _selectedFields = {};
  static const List<String> _exportMimeTypeOptions = [MimeTypes.csv, MimeTypes.json];
  late String _exportMimeType;
  final ValueNotifier<bool> _isValidNotifier = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _exportMimeType = MimeTypes.csv;
    _validate();
  }

  @override
  void dispose() {
    _isValidNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AvesDialog(
      title: l10n.settingsActionExport,
      scrollableContent: [
        TextDropdownButton<String>(
          values: _exportMimeTypeOptions,
          valueText: MimeUtils.displayType,
          value: _exportMimeType,
          onChanged: (v) {
            _exportMimeType = v!;
            setState(() {});
          },
          isExpanded: true,
          dropdownColor: Themes.thirdLayerColor(context),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        ..._entryFieldOptions.map(_toTile),
      ],
      actions: [
        const CancelButton(),
        ValueListenableBuilder<bool>(
          valueListenable: _isValidNotifier,
          builder: (context, isValid, child) {
            return TextButton(
              onPressed: isValid ? () => _submit(context) : null,
              child: Text(context.l10n.applyButtonLabel),
            );
          },
        ),
      ],
    );
  }

  Widget _toTile(ExportableEntryField field) {
    return SwitchListTile(
      value: _selectedFields.contains(field),
      onChanged: (selected) {
        selected ? _selectedFields.add(field) : _selectedFields.remove(field);
        setState(_validate);
      },
      title: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedText(
          textSpans: [
            TextSpan(
              text: field.getText(context),
              style: TextStyle(
                shadows: HighlightTitle.shadows(context),
              ),
            ),
          ],
          outlineColor: Themes.firstLayerColor(context),
        ),
      ),
    );
  }

  void _validate() => _isValidNotifier.value = _selectedFields.isNotEmpty;

  void _submit(BuildContext context) => Navigator.maybeOf(context)?.pop((_exportMimeType, _selectedFields));
}

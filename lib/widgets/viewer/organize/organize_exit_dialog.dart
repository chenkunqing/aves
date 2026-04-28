import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:aves/widgets/dialogs/aves_dialog.dart';
import 'package:flutter/material.dart';

Future<bool?> showOrganizeExitDialog(BuildContext context, int count) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      final l10n = context.l10n;
      return AvesDialog(
        content: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(l10n.organizeExitConfirmationMessage(count)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.entryActionDelete),
          ),
        ],
      );
    },
    routeSettings: const RouteSettings(name: AvesDialog.confirmationRouteName),
  );
}

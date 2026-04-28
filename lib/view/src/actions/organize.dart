import 'package:aves/theme/icons.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:aves_model/aves_model.dart';
import 'package:flutter/widgets.dart';

extension ExtraOrganizeActionView on OrganizeAction {
  String getText(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      OrganizeAction.showInCollection => l10n.slideshowActionShowInCollection,
    };
  }

  Widget getIcon() => Icon(_getIconData());

  IconData _getIconData() {
    return switch (this) {
      OrganizeAction.showInCollection => AIcons.allCollection,
    };
  }
}

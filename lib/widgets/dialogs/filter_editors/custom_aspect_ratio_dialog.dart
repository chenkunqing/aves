import 'package:aves/model/filters/aspect_ratio.dart';
import 'package:aves/model/filters/query.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:aves/widgets/common/providers/media_query_data_provider.dart';
import 'package:aves/widgets/dialogs/aves_dialog.dart';
import 'package:flutter/material.dart';

class CustomAspectRatioDialog extends StatefulWidget {
  static const routeName = '/dialog/custom_aspect_ratio';

  const CustomAspectRatioDialog({super.key});

  @override
  State<CustomAspectRatioDialog> createState() => _CustomAspectRatioDialogState();

  static String promptLabel(BuildContext context) => context.locale.startsWith('zh') ? '\u81ea\u5b9a\u4e49\u6bd4\u4f8b' : 'Custom ratio';
}

class _CustomAspectRatioDialogState extends State<CustomAspectRatioDialog> {
  final TextEditingController _ratioController = TextEditingController();
  final TextEditingController _toleranceController = TextEditingController(text: '0.01');

  AspectRatioFilter? _filter;
  String? _ratioErrorText, _toleranceErrorText;

  @override
  void dispose() {
    _ratioController.dispose();
    _toleranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final texts = _DialogTexts.of(context);
    _recomputeValidation(texts);
    return MediaQueryDataProvider(
      child: Builder(
        builder: (context) {
          return AvesDialog(
            title: CustomAspectRatioDialog.promptLabel(context),
            scrollableContent: [
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextField(
                  controller: _ratioController,
                  decoration: InputDecoration(
                    labelText: texts.ratioLabel,
                    helperText: _ratioErrorText == null ? texts.ratioHelp : null,
                    errorText: _ratioErrorText,
                  ),
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() => _recomputeValidation(texts)),
                  onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextField(
                  controller: _toleranceController,
                  decoration: InputDecoration(
                    labelText: texts.toleranceLabel,
                    helperText: _buildToleranceHelperText(texts),
                    errorText: _toleranceErrorText,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() => _recomputeValidation(texts)),
                  onSubmitted: (_) => _submit(context),
                ),
              ),
              const SizedBox(height: 8),
            ],
            actions: [
              const CancelButton(),
              TextButton(
                onPressed: _filter != null ? () => _submit(context) : null,
                child: Text(context.l10n.applyButtonLabel),
              ),
            ],
          );
        },
      ),
    );
  }

  void _recomputeValidation(_DialogTexts texts) {
    final parsedRatio = AspectRatioFilter.tryParseRatio(_ratioController.text);
    final tolerance = double.tryParse(_toleranceController.text.trim());

    _ratioErrorText = parsedRatio == null ? texts.ratioError : null;
    _toleranceErrorText = tolerance == null || tolerance < 0 ? texts.toleranceError : null;

    _filter = parsedRatio != null && tolerance != null && tolerance >= 0
        ? AspectRatioFilter(
            parsedRatio.$1,
            QueryFilter.opEqual,
            tolerance: tolerance,
            ratioText: parsedRatio.$2,
          )
        : null;
  }

  String _buildToleranceHelperText(_DialogTexts texts) {
    final filter = _filter;
    if (filter == null) return texts.toleranceHelp;

    final minRatio = AspectRatioFilter.formatNumber(filter.threshold - filter.tolerance);
    final maxRatio = AspectRatioFilter.formatNumber(filter.threshold + filter.tolerance);
    return texts.preview(minRatio, maxRatio);
  }

  void _submit(BuildContext context) {
    final filter = _filter;
    if (filter != null) {
      Navigator.maybeOf(context)?.pop(filter);
    }
  }
}

class _DialogTexts {
  final bool isChinese;

  const _DialogTexts._(this.isChinese);

  factory _DialogTexts.of(BuildContext context) => _DialogTexts._(context.locale.startsWith('zh'));

  String get ratioLabel => isChinese ? '\u76ee\u6807\u6bd4\u4f8b' : 'Target ratio';

  String get toleranceLabel => isChinese ? '\u5bb9\u5dee' : 'Tolerance';

  String get ratioHelp => isChinese ? '\u652f\u6301 3:4\u30014/3 \u6216 0.75' : 'Supports 3:4, 4/3 or 0.75';

  String get toleranceHelp => isChinese ? '\u4f8b\u5982 0.01' : 'For example 0.01';

  String get ratioError => isChinese ? '\u8bf7\u8f93\u5165\u5408\u6cd5\u6bd4\u4f8b' : 'Enter a valid ratio';

  String get toleranceError => isChinese ? '\u8bf7\u8f93\u5165\u5927\u4e8e\u6216\u7b49\u4e8e 0 \u7684\u5bb9\u5dee' : 'Enter a tolerance greater than or equal to 0';

  String preview(String minRatio, String maxRatio) => isChinese ? '\u5339\u914d\u8303\u56f4\uff1a$minRatio - $maxRatio' : 'Matches ratios from $minRatio to $maxRatio';
}
